#!/bin/sh


## Strace

# Install agent
kubectl apply -f strace/agent-daemonset.yaml

# Deploy debug Pod
kubectl apply -f strace/web-pod.yaml

# Try debugging
kubectl-debug web --agentless=false --port-forward=true 
strace -c -p1


# Install Netperf Operator
git clone https://github.com/piontec/netperf-operator.git 

kubectl apply -f netperf-operator/deploy/crd.yaml
kubectl apply -f netperf-operator/deploy/rbac.yaml
kubectl apply -f netperf-operator/deploy/operator.yaml

# Start the Test
kubectl apply -f netperf-operator/deploy/cr.yaml

kubectl describe netperf example

kubectl delete -f netperf-operator/deploy/cr.yaml

# Apply NetworkPolicy
kubectl apply -f kit/netperf-calico-policy.yaml

# Check node iptables counters
iptables --list -nv | grep DROP
iptables --list -nv | grep LOG
journalctl -k | grep calico

# Install Iptables-tailer
kubectl apply -f ./kit/

# Check events
kubectl get events -A
kubectl describe pod --selector=app=netperf-operator
