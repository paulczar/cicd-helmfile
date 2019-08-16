#!/bin/bash

# relative or absolute path of your envs directory, effectively where the directory
# containing this script sits relative to the helmfile dir.
export ENV_DIR="./envs/cicd/"


## General
# the base DNS name to build on top of, this should be registed as a
# managed domain in google cloud
export BASE_DOMAIN=cicd.kubernetes.wtf
# the DNS name of your PKS cluster
export PKS_HOSTNAME=pks.${BASE_DOMAIN}
# the location of the root_ca_certificate (download from opsman)
export ROOT_CA_CERT=~/Downloads/root_ca_certificate
#AWS creds
export AWS_SECRET_KEY=
export AWS_ACCESS_KEY=

# full URL for UAA, should be okay to let it derive it.
export UAA_URL=https://${PKS_HOSTNAME}:8443
export UAA_ADMIN_PASS=

# ## Cluster
# # The name of your PKS cluster (will create LB named this)
# # and other Cluster / GCP infra details
# export CLUSTER_NAME=cicd
# export CLUSTER_NETWORK=pks-network
# export CLUSTER_PROJECT=
# export CLUSTER_UUID=
# export CLUSTER_REGION=us-central1

## external-dns
# DNS domain for external-dns controller to manage
export EXTERNAL_DNS_DOMAIN="${BASE_DOMAIN}"

## concourse
# The UAA/OIDC user to add to 'main' group in concourse.
export CONCOURSE_OIDC_USER=paul
# hostname to register in DNS
export CONCOURSE_DNS=concourse.${EXTERNAL_DNS_DOMAIN}
# password for concourse admin user
export CONCOURSE_ADMIN_PASSWORD=change-this
# client id and secret for concourse to auth against UAA
export CONCOURSE_OIDC_CLIENT_ID=concourse-cicd
export CONCOURSE_OIDC_CLIENT_SECRET=a-bad-client-secret

## harbor
# hostname to register in DNS
export HARBOR_DNS=harbor.${EXTERNAL_DNS_DOMAIN}
# S3 bucket to store images in
export HARBOR_S3_BUCKET=cicd-harbor
# A bunch of passwords and secrets that you should change
export HARBOR_ADMIN_PASSWORD=change-me-please
export HARBOR_SECRET_KEY=not-a-secure-key
export HARBOR_DATABASE_PASSWORD=database-password
export HARBOR_INTERNAL_SECRET=not-a-good-secret
# UAA/OIDC client id/secret to use to auth against UAA
export HARBOR_UAA_CLIENT_ID=harbor-cicd
export HARBOR_UAA_CLIENT_SECRET=a-bad-client-secret

## Spinnaker

# UAA/OIDC client settings for Spinnaker
export SPINNAKER_DNS=spinnaker.${EXTERNAL_DNS_DOMAIN}
export SPINNAKER_GATE_DNS=gate.${SPINNAKER_DNS}
export SPINNAKER_UAA_CLIENT_ID=spinnaker-cicd
export SPINNAKER_UAA_CLIENT_SECRET=this-is-a-bad-client-secret
export SPINNAKER_S3_BUCKET=cicd-spinnaker
export SPINNAKER_REGISTRY_PASSWORD=change-to-your-docker-registry-password