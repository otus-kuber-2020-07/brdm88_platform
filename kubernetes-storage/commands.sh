#!/bin/sh


## CSI Driver Installation

# Change to the latest supported snapshotter version
SNAPSHOTTER_VERSION=v2.0.1

# Apply VolumeSnapshot CRDs
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

# Create snapshot controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

# Clone the repo
https://github.com/kubernetes-csi/csi-driver-host-path
# Deploy
csi-driver-host-path/deploy/kubernetes-1.20/deploy.sh


## Apply our Manifests
kubectl apply -f hw/

# Check
kubectl get pv
kubectl get pvc

# Connect to pod and test storage
#kubectl exec -it storage-pod -- /bin/sh
kubectl exec -it storage-pod echo Test123 > /data/file1.txt && cat /data/file1.txt
