#!/bin/sh

set -e

cd $(cd -P -- "$(dirname -- "$0")" && pwd -P)

. configuration

./binary-authorization-setup.sh
./cloudbees-setup.sh
./jenkinsfile-setup.sh
./cleanup.sh