# CloudBees Core Integration with Binary Authorization

This application demonstrates how to use Google Cloud's [Binary Authorization](https://cloud.google.com/binary-authorization/docs/overview) to validate and approve container images before deploying them to Google Kubernetes Engine (GKE) with [CloudBees Core](https://www.cloudbees.com/get-started). 

The demonstration used the [Spring Petclinic](https://github.com/spring-projects/spring-petclinic) application as a sample application but the same methodology would apply to any application that is being deploying on Kubernetes.

## Goals
Choices were made in the Jenknisfile Pipeline for this application to highlight several features but are not the only way to accomplish this integration. 

* Provide an extensible integration that can be used for different combinations of CloudBees Core and GCP. E.g. Multiple Projects, Multiple Namespaces.
* Provide compartmentalized steps that can be used independently in different Jenkins Pipelines. E.g. Kaniko build, Attestation Signing.
* Demonstrate conditional flow control of Jenknis Declarative Pipeline using _environment_ and _when_ based on presence of git tags. 

## Prerequisites
These items must be available to run this demonstration. 

### Cloud Environment
  * __Google Cloud Platform (GCP) Project__ - This demonstration was built to run on GCP specifically. Substitutions for any component will require changes to the demonstration.
    * [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/) - At least one Kubernetes cluster must be available to deploy application and for running pipeline. 
    * [Google Container Registry](https://cloud.google.com/container-registry/docs/quickstart) - The application container image will be uploaded to GCR for verification and deployed from GCR.
  * __CloudBees Core__ - This demonstration was built using CloudBees Core running on GKE. You can quickly install [CloudBees Core on GKE](https://console.cloud.google.com/marketplace/details/cloudbees/cloudbees-core) using the GCP Marketplace.
  * __GitHub or Bitbucket account__ - It is highly recommended to use GitHub, Bitbucket or Gitea support for this demonstration because they have support for Tags. For Gitea you will need to make sure it is available on the internet.

### Local Tools
  * Linux or OS-X (for setup) - The setup scripts provided will only work on Linux or OS-X
  * [gcloud](https://cloud.google.com/sdk/install)
  * [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  * [gpg2](https://gnupg.org/download/)

## Running the Demo

### Simple Installation
All of the setps needed to set up this demonstration are provided in the _setup_ directory. This setup assumes that you have a GCP project available for testing that can be cleaned up easily and not affect other workloads. The setup process will create several items in your GCP project including: [container analysis note](https://cloud.google.com/container-analysis/api/reference/rest/v1alpha1/projects.notes),[attestor](https://cloud.google.com/binary-authorization/docs/key-concepts#attestors) and a [service account](https://cloud.google.com/iam/docs/understanding-service-accounts).

#### Steps:
1. Fork and clone this repository
2. Edit [setup/configuration ](./setup/configuration)
3. Run [setup/setup.sh](./setup/setup.sh) - this script will make several changes to your GCP Project and create a Jenkinsfile for you.
4. Commit and Push changes back to your repository
5. Create a [Multibranch Pipeline](https://jenkins.io/doc/book/pipeline/multibranch/) in Jenkins for your repository and enable [Tag Discovery](https://jenkins.io/blog/2018/05/16/pipelines-with-git-tags/) 

### Setup scripts
The setup.sh script runs multiple scripts to set up a particular part of the demonstration. Each of these scripts can also be run independently if you want to have more control of the installation or skip different steps.

  * [binary-authorization-setup](./setup/binary-authorization-setup.sh) 
  * [cloudbees-setup](./setup/cloudbees-setup.sh)
  * [jenkinsfile-setup](./setup/jenkinsfile-setup.sh)
  * [cleanup](./setup/cleanup.sh)

###Watch Video Walkthrough

[![Video Walkthrough](http://img.youtube.com/vi/iHz1VBw_oZs/0.jpg)](https://www.youtube.com/watch?v=iHz1VBw_oZs)