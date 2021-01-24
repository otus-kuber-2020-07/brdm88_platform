#!/bin/bash

# Depoly Hipster Shop App
kubectl create ns microservices-demo
kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Logging/microservices-demo-without-resources.yaml -n microservices-demo

kubectl get pods -n microservices-demo -o wide

## Deploy EFK Stack
helm repo add elastic https://helm.elastic.co
kubectl create ns observability

# ElasticSearch
helm upgrade --install elasticsearch elastic/elasticsearch \
--namespace observability \
-f elasticsearch-values.yaml

# Nginx Ingress
kubectl create ns nginx-ingress

helm upgrade --install nginx-ingress stable/nginx-ingress --wait \
--namespace nginx-ingress \
--version=1.41.3 \
-f nginx-ingress-values.yaml

# Kibana
helm upgrade --install kibana elastic/kibana \
--namespace observability \
-f kibana-values.yaml

# Fluent Bit
helm upgrade --install fluent-bit stable/fluent-bit \
--namespace observability \
-f fluentbit-values.yaml

# Prometheus Operator
helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack --wait \
--namespace observability \
-f prometheus-values.yaml

# Elasticsearch Exporter
helm upgrade --install elasticsearch-exporter stable/elasticsearch-exporter \
--set es.uri=http://elasticsearch-master:9200 \
--set serviceMonitor.enabled=true \
--namespace=observability

#Loki
helm repo add loki https://grafana.github.io/loki/charts

helm upgrade --install loki loki/loki-stack \
--namespace observability \
-f loki-values.yaml