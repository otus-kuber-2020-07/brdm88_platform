#!/bin/bash

## Listing of commands used to deploy the needed entities for the Homework

# Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create ns monitoring

helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack --wait \
--namespace monitoring \
-f prometheus-operator/values.yaml

# Nginx custom workload
kubectl create ns nginx
kubectl apply -n nginx -f nginx-custom/

