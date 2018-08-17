#!/bin/bash

set -e
cd $(cd -P -- "$(dirname -- "$0")" && pwd -P)

# Refer to latest Documentation for help
# https://cloud.google.com/binary-authorization/docs/creating-attestors

# Load the configuration file so that all variables have context
. configuration

# echo "Setting gcloud project context to ${DEPLOYER_PROJECT_ID}"
# gcloud config set project ${DEPLOYER_PROJECT_ID}
# echo "Enabling required apis on project"

# Get Service Accounts for Deployer Project and Attestor Project to enable binary authorization service
DEPLOYER_PROJECT_NUMBER=$(gcloud projects describe "${DEPLOYER_PROJECT_ID}" --format="value(projectNumber)")
ATTESTOR_PROJECT_NUMBER=$(gcloud projects describe "${ATTESTOR_PROJECT_ID}" --format="value(projectNumber)")
DEPLOYER_SERVICE_ACCOUNT="service-${DEPLOYER_PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"
ATTESTOR_SERVICE_ACCOUNT="service-${ATTESTOR_PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"


echo "Generating json for Build Attestor container analysis note"
cat > /tmp/build_note_payload.json << EOM
{
  "name": "projects/${ATTESTOR_PROJECT_ID}/notes/${BUILD_ATTESTOR_NOTE_ID}",
  "attestation_authority": {
    "hint": {
      "human_readable_name": "Note for Binary Authorization Demo Build Attestor"
    }
  }
}
EOM

echo "Generating json for TAg Attestor container analysis note"
cat > /tmp/tag_note_payload.json << EOM
{
  "name": "projects/${ATTESTOR_PROJECT_ID}/notes/${TAG_ATTESTOR_NOTE_ID}",
  "attestation_authority": {
    "hint": {
      "human_readable_name": "Note for Binary Authorization Demo Tag Attestor"
    }
  }
}
EOM

# Display the json created for this step
# cat /tmp/note_payload.json

# Create Container Analysis Build Note using the API
echo "Creating Container Analysis Note"
curl -X POST \
 -H "Content-Type: application/json" \
 -H "Authorization: Bearer $(gcloud auth print-access-token)"  \
 --data-binary @/tmp/build_note_payload.json  \
"https://containeranalysis.googleapis.com/v1beta1/projects/${ATTESTOR_PROJECT_ID}/notes/?noteId=${BUILD_ATTESTOR_NOTE_ID}"

# Create Container Analysis Tag Note using the API
echo "Creating Container Analysis Note"
curl -X POST \
 -H "Content-Type: application/json" \
 -H "Authorization: Bearer $(gcloud auth print-access-token)"  \
 --data-binary @/tmp/tag_note_payload.json  \
"https://containeranalysis.googleapis.com/v1beta1/projects/${ATTESTOR_PROJECT_ID}/notes/?noteId=${TAG_ATTESTOR_NOTE_ID}"

# Validate that the notes were created properly
echo "Existing container notes on Attestor Project:"
curl \
   -H "Authorization: Bearer $(gcloud auth print-access-token)"  \
   "https://containeranalysis.googleapis.com/v1beta1/projects/${ATTESTOR_PROJECT_ID}/notes/"


echo "Generating json for iam policy for service accounts to access build note"
cat > /tmp/build_iam_request.json << EOM
{
  "resource": "projects/${ATTESTOR_PROJECT_ID}/notes/${BUILD_ATTESTOR_NOTE_ID}",
  "policy": {
    "bindings": [
      {
        "role": "roles/containeranalysis.notes.occurrences.viewer",
        "members": [
          "serviceAccount:${DEPLOYER_SERVICE_ACCOUNT}",
          "serviceAccount:${ATTESTOR_SERVICE_ACCOUNT}",
        ]
      }
    ]
  }
}
EOM

echo "Generating json for iam policy for service accounts to access tag note"
cat > /tmp/tag_iam_request.json << EOM
{
  "resource": "projects/${ATTESTOR_PROJECT_ID}/notes/${TAG_ATTESTOR_NOTE_ID}",
  "policy": {
    "bindings": [
      {
        "role": "roles/containeranalysis.notes.occurrences.viewer",
        "members": [
          "serviceAccount:${DEPLOYER_SERVICE_ACCOUNT}",
          "serviceAccount:${ATTESTOR_SERVICE_ACCOUNT}",
        ]
      }
    ]
  }
}
EOM

# Display the json created for this step
# cat /tmp/iam_request.json

# Update the IAM policy on the build note created in the last step.
echo "Updating IAM policy on ${BUILD_ATTESTOR_NOTE_ID} to allow ${DEPLOYER_SERVICE_ACCOUNT} and ${ATTESTOR_SERVICE_ACCOUNT} access"
curl -X POST  \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  --data-binary @/tmp/build_iam_request.json \
  "https://containeranalysis.googleapis.com/v1alpha1/projects/${ATTESTOR_PROJECT_ID}/notes/${BUILD_ATTESTOR_NOTE_ID}:setIamPolicy"

# Update the IAM policy on the tag note created in the last step.
echo "Updating IAM policy on ${TAG_ATTESTOR_NOTE_ID} to allow ${DEPLOYER_SERVICE_ACCOUNT} and ${ATTESTOR_SERVICE_ACCOUNT} access"
curl -X POST  \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  --data-binary @/tmp/tag_iam_request.json \
  "https://containeranalysis.googleapis.com/v1alpha1/projects/${ATTESTOR_PROJECT_ID}/notes/${TAG_ATTESTOR_NOTE_ID}:setIamPolicy"

echo "Setting up Attestors"

echo "Generating public and private key for attestor account ${BUILD_ATTESTOR_ID}"
gpg --batch --gen-key <(
  cat << EOM
    Key-Type: RSA
    Key-Length: 2048
    Name-Real: ${BUILD_ATTESTOR_NAME}
    Name-Email: ${BUILD_ATTESTOR_EMAIL}
    %no-protection
    %commit
EOM
)

echo "Generating public and private key for attestor account ${TAG_ATTESTOR_ID}"
gpg --batch --gen-key <(
  cat << EOM
    Key-Type: RSA
    Key-Length: 2048
    Name-Real: ${TAG_ATTESTOR_NAME}
    Name-Email: ${TAG_ATTESTOR_EMAIL}
    %no-protection
    %commit
EOM
)

echo "Exporting private and public keys for Attestors"
gpg --armor --export-secret-key "${BUILD_ATTESTOR_NAME} <${BUILD_ATTESTOR_EMAIL}>" > /tmp/${BUILD_ATTESTOR_ID}.key
gpg --armor --export-secret-key "${TAG_ATTESTOR_NAME} <${TAG_ATTESTOR_EMAIL}>" > /tmp/${TAG_ATTESTOR_ID}.key
gpg --armor --export ${BUILD_ATTESTOR_EMAIL} > /tmp/${BUILD_ATTESTOR_ID}-pub.pgp
gpg --armor --export ${TAG_ATTESTOR_EMAIL} > /tmp/${TAG_ATTESTOR_ID}-pub.pgp

# Create Attestor in Attestor Project. If this Attestor already exists delete and recreate it.
if [[ $(gcloud beta container binauthz attestors list --project=${ATTESTOR_PROJECT_ID} --format="value(name)") =~ (^|[[:space:]])${BUILD_ATTESTOR_ID}($|[[:space:]]) ]]
  then
    echo "Deleting Existing Build Attestor"
    gcloud beta container binauthz attestors delete ${BUILD_ATTESTOR_ID} \
    --project=${ATTESTOR_PROJECT_ID}  
fi 

# If this Tag Attestor already exists delete and recreate it.
if [[ $(gcloud beta container binauthz attestors list --project=${ATTESTOR_PROJECT_ID} --format="value(name)") =~ (^|[[:space:]])${TAG_ATTESTOR_ID}($|[[:space:]]) ]]
  then
    echo "Deleting Existing Tag Attestor"
    gcloud beta container binauthz attestors delete ${TAG_ATTESTOR_ID} \
      --project=${ATTESTOR_PROJECT_ID} 
fi 


echo "Creating new Build Attestor"
gcloud beta container binauthz attestors create ${BUILD_ATTESTOR_ID} \
  --project=${ATTESTOR_PROJECT_ID} \
  --attestation-authority-note=${BUILD_ATTESTOR_NOTE_ID} \
  --attestation-authority-note-project=${ATTESTOR_PROJECT_ID} \
  --description="Attestor to verify that the image was built successfully for testing"

echo "Creating new Tag Attestor"
gcloud beta container binauthz attestors create ${TAG_ATTESTOR_ID} \
  --project=${ATTESTOR_PROJECT_ID} \
  --attestation-authority-note=${TAG_ATTESTOR_NOTE_ID} \
  --attestation-authority-note-project=${ATTESTOR_PROJECT_ID} \
  --description="Attestor to verify that the image was tagged as a trusted release for production"

# Add public key for Attestor
echo "Adding public key for Attestor"
gcloud --project=${ATTESTOR_PROJECT_ID} \
  beta container binauthz attestors public-keys add \
  --attestor=${BUILD_ATTESTOR_ID} \
  --public-key-file=/tmp/${BUILD_ATTESTOR_ID}-pub.pgp

# Add public key for TAG Attestor
echo "Adding public key for Attestor"
gcloud --project=${ATTESTOR_PROJECT_ID} \
  beta container binauthz attestors public-keys add \
  --attestor=${TAG_ATTESTOR_ID} \
  --public-key-file=/tmp/${TAG_ATTESTOR_ID}-pub.pgp

# Create IAM policy for Deployer Service Account to verify from Attestor.
# Note: glcoud command from documents does not work correctly
#
# https://cloud.google.com/binary-authorization/docs/creating-attestors
#
# gcloud beta container binauthz attestors set-iam-policy \
# "projects/${ATTESTOR_PROJECT_ID}/attestors/my-attestor" \
#  --member="serviceAccount:${DEPLOYER_SERVICE_ACCOUNT}" \
#  --role=roles/binaryauthorization.attestorsVerifier
#  
# --member and --role are not recognized. set-iam-policy expects json file

cat > /tmp/verifier_iam_policy.json << EOM
  {
    "bindings": [
      {
        "role": "roles/binaryauthorization.attestorsVerifier",
        "members": [
          "serviceAccount:${DEPLOYER_SERVICE_ACCOUNT}"
        ]
      }
    ] 
  }
EOM

# Grant permission for Deployer Service account to verify containers
echo "Granting permission for Deployer service account to verify contiainer"
gcloud beta container binauthz attestors set-iam-policy \
  "projects/${ATTESTOR_PROJECT_ID}/attestors/${BUILD_ATTESTOR_ID}" \
  /tmp/verifier_iam_policy.json

# Grant permission for Deployer Service account to verify containers
echo "Granting permission for Deployer service account to verify contiainer"
gcloud beta container binauthz attestors set-iam-policy \
  "projects/${ATTESTOR_PROJECT_ID}/attestors/${TAG_ATTESTOR_ID}" \
  /tmp/verifier_iam_policy.json