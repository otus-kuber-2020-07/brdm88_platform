#!/bin/bash

# Clone microservices-demo repository
git clone https://github.com/GoogleCloudPlatform/microservices-demo
cd microservices-demo
git remote add gitlab git@gitlab.com:brdm88/microservices-demo.git
git remote remove origin
git push gitlab master

# Creating GKE Cluster
gcloud beta container clusters create k8s-gitops \
    --zone europe-west1-b \
    --num-nodes 4 \
    --machine-type n1-standard-2 \
    --no-enable-stackdriver-kubernetes \
    #--addons=Istio \
    #--istio-config=auth=MTLS_PERMISSIVE

# Delete GKE Cluster
gcloud container clusters delete k8s-gitops \
    --zone europe-west1-b

# Build Docker images of 'microservices-demo'
tag=v0.0.1
for srv in $(ls microservices-demo/src); do
echo "Building Docker image of "$srv" with tag "$tag"...";
  docker build -t brdm88/$srv:$tag microservices-demo/src/$srv;
  docker push brdm88/$srv:$tag;
  echo "------------------------------";
done


## Flux deploy

# CRD
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/flux-helm-release-crd.yaml

# Flux
helm repo add fluxcd https://charts.fluxcd.io

kubectl create namespace flux
helm upgrade --install flux fluxcd/flux \
--namespace flux \
-f flux-values.yaml 

# Helm operator
helm upgrade --install helm-operator fluxcd/helm-operator \
--namespace flux \
-f helm-operator-values.yaml

# Config Flux SSH key
fluxctl identity --k8s-fwd-ns flux

# Flux manual sync
fluxctl --k8s-fwd-ns flux sync


### ===============================

## Istio install
kubectl create namespace istio-system
stioctl install --set meshConfig.accessLogFile=/dev/stdout


## Flagger install
helm repo add flagger https://flagger.app

kubectl apply -f https://raw.githubusercontent.com/weaveworks/flagger/master/artifacts/flagger/crd.yaml

helm upgrade --install flagger flagger/flagger \
--namespace=istio-system \
--set crd.create=false \
--set meshProvider=istio \
--set metricsServer=http://prometheus-operated:9090
#--set metricsServer=http://prometheus-operated.observability.svc.cluster.local:9090


# Nginx Ingress
kubectl create ns nginx-ingress
helm upgrade --install nginx-ingress stable/nginx-ingress --wait \
--namespace nginx-ingress \
--version=1.41.3

# Prometheus
helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack --wait \
--namespace istio-system \
-f prometheus-values.yaml
