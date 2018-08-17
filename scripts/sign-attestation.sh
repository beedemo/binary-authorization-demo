#!/bin/sh
set -e

if [ $# -ne 6 ];
    then echo "Usage: sign-attestation.sh <path to service acct key> <path to attestor private key> <attestor name> <attestor email> <attestation project> <image:tag>"
    exit 1
fi

# args
# 1 path to service account that has access to deploy
SVC_ACCT=$1
# 2 path to the private key of the attestor
ATTESTOR_PRIVATE_KEY=$2
# 3 name of the attestor to use
ATTESTOR_ID=$3
# 4 email address of the attestor
ATTESTOR_EMAIL=$4
# 5 project that contains attestations
ATTESTOR_PROJECT=$5
# 6 Full image url and tag of container to deploy
DEPLOY_IMAGE=$6

#check if gpg is installed locally and install if not
if ! ( hash gpg 2>/dev/null ); then 
  apt-get update apt-get install gnupg2 -y
fi

#check if gcloud is installed and install it if not
if ! ( hash gcloud 2>/dev/null ); then
  export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
  echo "deb http://packages.cloud.google.com/apt ${CLOUD_SDK_REPO} main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  apt-get update && apt-get install google-cloud-sdk -y
fi

# authenticate service accout with required permissions to sign attestation
gcloud auth activate-service-account --key-file=${SVC_ACCT} --no-user-output-enabled
# generate full url of the image to sign
ARTIFACT_URL="$(gcloud container images describe ${DEPLOY_IMAGE} --format='value(image_summary.fully_qualified_digest)')"
# create a temporary payload json that will be used to create our signed attestation
gcloud beta container binauthz create-signature-payload --artifact-url=${ARTIFACT_URL} > /tmp/generated_payload.json
# import the private key from attestor
gpg --allow-secret-key-import --import ${ATTESTOR_PRIVATE_KEY}
# create signature from payload of image
gpg --local-user ${ATTESTOR_EMAI}L --armor --output /tmp/generated_signature.pgp --sign /tmp/generated_payload.json
# create attestation using signature created
gcloud beta container binauthz attestations create --artifact-url="${ARTIFACT_URL}" \
  --attestor="projects/${ATTESTOR_PROJECT}/attestors/${ATTESTOR_ID}" --signature-file=/tmp/generated_signature.pgp \
  --pgp-key-fingerprint="$(gpg --with-colons --fingerprint ${ATTESTOR_EMAIL} | awk -F: '$1 == "fpr" {print $10;exit}')"

echo "Attestation created by Attestor: ${ATTESTOR_ID} for Image: ${ARTIFACT_URL}"
