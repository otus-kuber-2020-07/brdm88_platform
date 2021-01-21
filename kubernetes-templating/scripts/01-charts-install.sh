#!/bin/bash

## GKE
gcloud auth application-default login
gcloud container clusters get-credentials $(terraform output kubernetes_cluster_name) --zone $(terraform output zone)

## Install charts from public repos.

# Nginx Ingress
helm repo add "stable" "https://charts.helm.sh/stable" --force-update
kubectl create ns nginx-ingress

helm upgrade --install nginx-ingress stable/nginx-ingress --wait \
--namespace=nginx-ingress \
--version=1.41.3


# Cert-Manager
helm repo add jetstack https://charts.jetstack.io
kubectl create ns cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.crds.yaml

helm upgrade --install cert-manager jetstack/cert-manager --wait \
--namespace=cert-manager \
--version=0.16.1

kubectl -n cert-manager apply -f kubernetes-templating/cert-manager/clusterissuer.yaml

# Chartmuseum
kubectl create ns chartmuseum
helm upgrade --install chartmuseum stable/chartmuseum --wait \
--namespace=chartmuseum \
--version=2.13.2 \
-f kubernetes-templating/chartmuseum/values.yaml


# Harbor
helm repo add harbor https://helm.goharbor.io
kubectl create ns harbor
helm upgrade --install harbor harbor/harbor --wait \
--namespace=harbor \
--version=1.1.2 \
-f kubernetes-templating/harbor/values.yaml
