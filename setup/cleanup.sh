#!/bin/bash

cd $(cd -P -- "$(dirname -- "$0")" && pwd -P)

# Load the configuration file so that all variables have context
. configuration

# remove all tmp files created during setup
echo "Removing all temporary files created by setup"
rm /tmp/${BUILD_ATTESTOR_ID}.key \
  /tmp/${BUILD_ATTESTOR_ID}-pub.pgp \
  /tmp/${TAG_ATTESTOR_ID}.key \
  /tmp/${TAG_ATTESTOR_ID}-pub.pgp \
  /tmp/build_iam_request.json \
  /tmp/build_note_payload.json \
  /tmp/tag_iam_request.json \
  /tmp/tag_note_payload.json \
  /tmp/cloudbees-secret.json \
  /tmp/verifier_iam_policy.json

# remove gpg keys for attestors 
echo "Removing GPG key created by setup for build attestor"
while 
  FINGERPRINT="$(gpg --with-colons --fingerprint ${BUILD_ATTESTOR_EMAIL} | awk -F: '$1 == "fpr" {print $10;exit}')"
  gpg --delete-secret-keys --yes --batch "${FINGERPRINT}"
  gpg --delete-key --batch "${FINGERPRINT}"
do :;
done

echo "Removing GPG key created by setup for tag attestor"
while 
  FINGERPRINT="$(gpg --with-colons --fingerprint ${TAG_ATTESTOR_EMAIL} | awk -F: '$1 == "fpr" {print $10;exit}')"
  gpg --delete-secret-keys --yes --batch "${FINGERPRINT}"
  gpg --delete-key --batch "${FINGERPRINT}"
do :;
done