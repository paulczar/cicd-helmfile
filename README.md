# CI/CD on Kubernetes Infrastructure

This project demonstrates how to set up and install CI/CD infrastructure on Kubernetes. It uses Pivotal Container Service (PKS) as the Kubernetes provider with RBAC being  provided by UAA, but most of this should work without, you'll just have to find an alternative authentication method for your apps.

We take advantage of a few tools to streamline things, firstly [Helm](https://helm.sh) as all of the infrastructure tooling is available in public Helm charts (although some charts may be vendored in here for custom changes). We also use Helmfile which is a project that allows you to compose Helm Charts together.

With the goal of doing a gitops style workflow for deploying this, it is expected that you'll have seperate `env` directory(s) containing the customizations for a particular environment or cluster. The example included is not fully functioning, but should be fairly simple to get working.

For the most part you should just need to edit `envs/cicd/envs.sh` and fill it in with your details. This is a shell script that will export environment variables to be used by Helmfile. The reason for this is that if you have passwords/secrets you can store them outside of git and have the script extract them from wherever you keep them.

## Download tools

It's expected that you already have the basic Kubernetes client tools like `kubectl` installed.

### Helm

* [helm](https://helm.sh/docs/using_helm/#quickstart-guide)
* [helmfile](https://github.com/roboll/helmfile#installation)
* [helmdiff](https://github.com/databus23/helm-diff#install)

## Prepare environment

### Create PKS Kubernetes Cluster

> Note: this assumes you already have a PKS cluster running with dns and is accesible via kubectl.


### Load up your PKS kubernetes creds

```bash
pks get-credentials <your-cluster>
```

ensure kubectl is working

```bash
$ kubectl get nodes
NAME                                      STATUS   ROLES    AGE   VERSION
vm-5ca56981-6249-4d31-613e-7d84821b245e   Ready    <none>   46m   v1.13.5
vm-5fb78083-d502-43b3-4e01-d664fdb147dc   Ready    <none>   42m   v1.13.5
vm-b451253c-e485-4d99-7bb4-1cfe222bf4ac   Ready    <none>   39m   v1.13.5
```

## Install Tiller

This will install Helm's Tiller securely

```bash
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account=tiller
kubectl -n kube-system delete service tiller-deploy
kubectl -n kube-system patch deployment tiller-deploy --patch '
spec:
  template:
    spec:
      containers:
        - name: tiller
          ports: []
          command: ["/tiller"]
          args: ["--listen=localhost:44134"]
'
```

check tiller is working:

```bash
$ helm version
Client: &version.Version{SemVer:"v2.14.0", GitCommit:"05811b84a3f93603dd6c2fcfe57944dfa7ab7fd0", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.14.0", GitCommit:"05811b84a3f93603dd6c2fcfe57944dfa7ab7fd0", GitTreeState:"clean"}
```

## Configuration
Copy `envs/cicd-template/` to `envs/cicd` this will be ignored by git since it will contain secrets

Poke through `envs/cicd/envs.sh` it should be pretty obvious what you need to set.

### Create s3 buckets

create a bucket matching the names you updated for `HARBOR_S3_BUCKET` and `SPINNAKER_S3_BUCKET` in the env.sh

### Default SC

make sure you have a default storage class set 

`kubectl apply -f ./resources/storageclass.yml`

### Configure ingress

Not really anything to do here, defaults should be fine.

### Configure cert-manager

Edit the file `../envs/cicd/cert-manager/cluster-issuer.yaml` and change the email address and access key for both Issuers.

Create a namespace for cert-manager to run in:

```bash
kubectl create namespace cluster-system
```

create the secret for the cert manager to use. 
```bash
kubectl -n cluster-system create secret generic route53-credentials-secret \
    --from-literal="secret-access-key=${AWS_SECRET_KEY}"
```

Apply the CRDs for cert-manager:

```bash
kubectl apply -f ./resources/cert-manager/crds.yaml
```

Create the cluster issuer:

```bash
kubectl apply -f ./envs/cicd/cert-manager/cluster-issuer.yaml
```

### Concourse

```bash
. ./envs/cicd/envs.sh
uaac target $UAA_URL --skip-ssl-validation
uaac token client get admin -s "$UAA_ADMIN_PASS"
uaac client add ${CONCOURSE_OIDC_CLIENT_ID} --scope openid,roles,uaa.user \
  --authorized_grant_types refresh_token,password,authorization_code \
  --redirect_uri "https://${CONCOURSE_DNS}/sky/issuer/callback" \
  --authorities clients.read,clients.secret,uaa.resource,scim.write,openid,scim.read \
  --secret "${CONCOURSE_OIDC_CLIENT_SECRET}"
```

### Harbor

Harbor will autogenerate certificates for notary, but it will regenerate them every time helm runs, which is painful. You can should create your own secret based on it, but we've provided a default to get you going:

```bash
kubectl create namespace harbor
kubectl -n harbor apply -f ./envs/cicd/harbor/notary-certs-secret.yaml
```

Harbor also needs your UAA server's CA Cert. You can create a secret for it like so:

```bash
. ./envs/cicd/envs.sh
kubectl -n harbor create secret generic \
   uaa-ca-cert --from-file=ca.crt=$ROOT_CA_CERT
```

You also need to create a client in your UAA server for harbor:

```bash
. ../envs/cicd/envs.sh
uaac client add ${HARBOR_UAA_CLIENT_ID} --scope openid \
  --authorized_grant_types client_credentials,password,refresh_token \
  --redirect_uri "https://${HARBOR_DNS}  https://${HARBOR_DNS}/*" \
  --secret "${HARBOR_UAA_CLIENT_SECRET}" \
  --authorities clients.read,clients.secret,uaa.resource,scim.write,openid,scim.read
```

### Spinnaker

Create a namespace for spinnaker:

```bash
kubectl create namespace spinnaker
```

In order for Spinnaker to trust UAA's CA CERT we need to construct a new java cert store that includes our UAA cert:
Note: If you're on a Mac, you'll need to run replace `/etc/ssl/certs/java/cacerts` with `$(/usr/libexec/java_home)/jre/lib/security/cacerts`

```bash
. ./envs/cicd/envs.sh
cp /etc/ssl/certs/java/cacerts /tmp/cacerts
echo "changeit" | keytool -importcert -alias uaa-ca \
    -keystore /tmp/cacerts -noprompt -file $ROOT_CA_CERT
kubectl -n spinnaker create secret generic \
    java-ca-certs --from-file /tmp/cacerts
```

Create a UAA client for spinnaker:

```bash
. ./envs/cicd/envs.sh
uaac client add "${SPINNAKER_UAA_CLIENT_ID}" \
  --scope openid,uaa.user,uaa.resource \
  --authorized_grant_types password,refresh_token,authorization_code,client_credentials \
  --redirect_uri "https://${SPINNAKER_GATE_DNS}/login" \
  --secret "${SPINNAKER_UAA_CLIENT_SECRET}" \
  --authorities uaa.resource
```

 Create a secret from the client secret we just created:

```bash
. ./envs/cicd/envs.sh
kubectl -n spinnaker create secret generic \
  spinnaker-additional-secrets \
  --from-literal="oauth2_client_secret=${SPINNAKER_UAA_CLIENT_SECRET}"
```

Create a secret for your registry auth:

```bash
. ./envs/cicd/envs.sh
kubectl -n spinnaker create secret generic registry-secret \
    --from-literal="harbor=${SPINNAKER_REGISTRY_PASSWORD}"
```
### create a UAA user

create a user in uaa

`uaac user add username -p 'pass' --emails email`

> Note: you will need to add items to the spinnkaer values for the images you want to make available to spinnaker after you deploy them. 

## Install that shizzle

```bash
helmfile apply
```

###enable UAA auth in harbor

```bash
curl -i -X PUT -u "admin:${HARBOR_ADMIN_PASSWORD}" \                                                                               ✔  13212  12:31:21
  -H "Content-Type: application/json" \
  https://${HARBOR_DNS}/api/configurations \
  -d '{"auth_mode":"uaa_auth","self_registration":"false","uaa_client_id":"harbor-cicd","uaa_client_secret":"'${HARBOR_UAA_CLIENT_SECRET}'","uaa_endpoint":"'${UAA_URL}'","uaa_verify_cert":"false"}'
  ```
