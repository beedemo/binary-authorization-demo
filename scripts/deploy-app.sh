#!/bin/sh
set -e

if [ $# -ne 6 ];
    then echo "Usage: deploy-app.sh <Path to SVC ACCT Key> <Target Cluster> <Target Project> <Target Zone> <Image> <Namespace>"
    exit 1
fi

#check if gcloud is installed and install it if not
if ! ( hash gcloud 2>/dev/null ); then
  export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
  echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  apt-get update && apt-get install google-cloud-sdk -y
fi


# args
# 1 path to service account that has access to deploy 
CLOUDBEES_SVC_ACCT_KEY=$1
# 2 name of the cluster where the application will be deployed 
TARGET_CLUSTER=$2
# 3 name of the GCP project where the applicaiton will be deployed 
TARGET_PROJECT=$3
# 4 zone of the cluster for deployment
TARGET_ZONE=$4
# 5 Full Name and tag of the Container Image to be deployed
DEPLOY_IMAGE=$5
# 6 Namespace of the Target Cluster to deploy application to
NAMESPACE=$6

#authenticate service accout with required permissions to deploy application
gcloud auth activate-service-account --key-file=$CLOUDBEES_SVC_ACCT_KEY --no-user-output-enabled 
# generate full url with digest to deploy. This format is required by Binary Authorization
ARTIFACT_URL="$(gcloud container images describe ${DEPLOY_IMAGE} --format='value(image_summary.fully_qualified_digest)')"
# configure and apply the proper context for kubectl
gcloud container clusters get-credentials ${TARGET_CLUSTER} --project ${TARGET_PROJECT} --zone ${TARGET_ZONE} --no-user-output-enabled
# update the deployment yaml with the image to be deployed
sed -i.bak "s#REPLACEME#${ARTIFACT_URL}#" ./k8s/deploy/petclinic-app-deploy.yaml  
# make sure the namepsace exists and create it if doesn't
kubectl get ns ${NAMESPACE} || kubectl create ns ${NAMESPACE}
# deploy the load balancer for the application
kubectl --namespace=${NAMESPACE} apply -f k8s/deploy/petclinic-service-deploy.yaml 
# deploy the application
kubectl --namespace=${NAMESPACE} apply -f k8s/deploy/petclinic-app-deploy.yaml  
# make sure that deployment succeeds. This will not fail until timeout is reached
kubectl rollout status deploy/petclinic-deploy -n ${NAMESPACE}

echo "Application is available at IP: "
kubectl describe services petclinic-lb -n ${NAMESPACE} | grep "LoadBalancer Ingress:"