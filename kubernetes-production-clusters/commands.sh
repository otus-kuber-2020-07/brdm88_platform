#!/bin/bash

## Create GCP Compute Instances

gcloud compute instances create kube-master   --image-family ubuntu-minimal-1804-lts --image-project ubuntu-os-cloud --zone europe-west1-b --machine-type=n1-standard-2 && \
gcloud compute instances create kube-worker-1 --image-family ubuntu-minimal-1804-lts --image-project ubuntu-os-cloud --zone europe-west1-b --machine-type=n1-standard-1 && \
gcloud compute instances create kube-worker-2 --image-family ubuntu-minimal-1804-lts --image-project ubuntu-os-cloud --zone europe-west1-b --machine-type=n1-standard-1 && \
gcloud compute instances create kube-worker-3 --image-family ubuntu-minimal-1804-lts --image-project ubuntu-os-cloud --zone europe-west1-b --machine-type=n1-standard-1

# Get SSH to Cloud VMs
gcloud compute ssh kube-master
gcloud compute ssh kube-worker-1
gcloud compute ssh kube-worker-2
gcloud compute ssh kube-worker-3

# Delete GCP VMs
gcloud compute instances delete kube-master   --zone europe-west1-b && \
gcloud compute instances delete kube-worker-1 --zone europe-west1-b && \
gcloud compute instances delete kube-worker-2 --zone europe-west1-b && \
gcloud compute instances delete kube-worker-3 --zone europe-west1-b



## Prepare the Nodes

# Turn off swap
sudo -i
swapoff -a

# Enable routing
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

# Install Docker
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

apt-get update && apt-get install -y containerd.io=1.2.13-1 docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)

# Install Docker Daemon.
cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
     },
    "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d && systemctl daemon-reload && systemctl restart docker

# Install kubelet, kubeadm, kubectl
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
apt-get install -y kubelet=1.17.4-00 kubeadm=1.17.4-00 kubectl=1.17.4-00

#####

## Create Cluster
kubeadm init --pod-network-cidr=192.168.0.0/24

# Copy kubectl config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Check
kubectl get nodes

## Install Network plugin
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml


## Connect Worker Nodes

# Get tokens list
kubeadm token list

# Get Hash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'

# Join
#kubeadm join --token <token> <master-ip>:<master-port> --discovery-token-ca-cert-hash sha256:<hash>

# Deplot test Workload
kubectl apply -f nginx-deploy.yaml


## Update cluster from ver. 1.17 to ver. 1.18 via kubeadm

apt-get update && apt-get install -y kubeadm=1.18.0-00 kubelet=1.18.0-00 kubectl=1.18.0-00

# Check components versions
kubeadm version
kubelet --version
kubectl version

kubectl -n kube-system describe po kube-apiserver-kube-master


# Upgrade k8s components
kubeadm upgrade plan
kubeadm upgrade apply v1.18.0


## Update worker nodes

# Drain node
kubectl drain kube-worker-1 --ignore-daemonsets

# Update node
apt-get install -y kubelet=1.18.0-00 kubeadm=1.18.0-00
systemctl restart kubelet

# Uncordon node
kubectl uncordon kube-worker-1

###

## Kubespray installation

git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
sudo pip3 install -r requirements.txt

# Copy the Inventory
cp -rfp inventory/sample inventory/mycluster

# Apply the Playbook
ansible-playbook -i inventory/mycluster/inventory.ini --become --become-user=root \
--user=${SSH_USERNAME} --key-file=${SSH_PRIVATE_KEY} cluster.yml



### Additional Task

gcloud compute instances create k8s-master-1 --image-family ubuntu-minimal-1804-lts --image-project ubuntu-os-cloud --zone europe-west1-b --machine-type=n1-standard-2 && \
gcloud compute instances create k8s-master-2 --image-family ubuntu-minimal-1804-lts --image-project ubuntu-os-cloud --zone europe-west1-b --machine-type=n1-standard-2 && \
gcloud compute instances create k8s-master-3 --image-family ubuntu-minimal-1804-lts --image-project ubuntu-os-cloud --zone europe-west1-b --machine-type=n1-standard-2 && \
gcloud compute instances create k8s-node-1 --image-family ubuntu-minimal-1804-lts --image-project ubuntu-os-cloud --zone europe-west1-b --machine-type=n1-standard-1 && \
gcloud compute instances create k8s-node-2 --image-family ubuntu-minimal-1804-lts --image-project ubuntu-os-cloud --zone europe-west1-b --machine-type=n1-standard-1

# Get SSH to Cloud VMs
gcloud compute ssh k8s-master-1
gcloud compute ssh k8s-master-2
gcloud compute ssh k8s-master-3
gcloud compute ssh k8s-node-1
gcloud compute ssh k8s-node-2

# Use Kubespray

cp -rfp inventory/sample inventory/multimaster

# Apply the Playbook
ansible-playbook -i inventory/multimaster/inventory-multimaster.ini \
--become --become-user=root cluster.yml


# Delete GCP VMs
gcloud compute instances delete k8s-master-1 --zone europe-west1-b && \
gcloud compute instances delete k8s-master-2 --zone europe-west1-b && \
gcloud compute instances delete k8s-master-3 --zone europe-west1-b && \
gcloud compute instances delete k8s-node-1 --zone europe-west1-b && \
gcloud compute instances delete k8s-node-2 --zone europe-west1-b

