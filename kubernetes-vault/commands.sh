#!/bin/sh

# Install Consul & Vault
git clone https://github.com/hashicorp/consul-helm.git
helm upgrade --install consul consul-helm

git clone https://github.com/hashicorp/vault-helm.git
helm upgrade --install vault vault-helm -f vault-values.yaml

# Init Vault
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1

kubectl exec -it vault-0 -- vault status

# Unseal Vault
kubectl exec -it vault-0 -- vault operator unseal
kubectl exec -it vault-1 -- vault operator unseal
kubectl exec -it vault-2 -- vault operator unseal

# Login to Vault
kubectl exec -it vault-0 -- vault auth list
kubectl exec -it vault-0 -- vault login

# Create Secrets
kubectl exec -it vault-0 -- vault secrets enable --path=otus kv
kubectl exec -it vault-0 -- vault secrets list --detailed
kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus' password='asajkjkahs'
kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus' password='asajkjkahs'
kubectl exec -it vault-0 -- vault read otus/otus-ro/config
kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config

# Enable k8s Auth
kubectl exec -it vault-0 -- vault auth enable kubernetes
kubectl exec -it vault-0 -- vault auth list

# Create a service account, 'vault-auth'
kubectl create serviceaccount vault-auth
# Update the 'vault-auth' service account
kubectl apply -f vault-auth-service-account.yml

# Set variables
export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
export K8S_HOST=$(more ~/.kube/config | grep server | awk '/http/ {print $NF}')
### alternative way
export K8S_HOST=$(kubectl cluster-info | grep ‘Kubernetes master’ | awk ‘/https/ {print $NF}’ | sed ’s/\x1b\[[0-9;]*m//g’ )

# Write the config
kubectl exec -it vault-0 -- vault write auth/kubernetes/config \
  token_reviewer_jwt="$SA_JWT_TOKEN" \
  kubernetes_host="$K8S_HOST" \
  kubernetes_ca_cert="$SA_CA_CRT"

# Create policy and role
kubectl cp otus-policy.hcl vault-0:./tmp
kubectl exec -it vault-0 -- vault policy write otus-policy /tmp/otus-policy.hcl
kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus \
  bound_service_account_names=vault-auth \
  bound_service_account_namespaces=default policies=otus-policy ttl=24h

# Check Authorization
#kubectl run tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7 apk add curl jq
kubectl run tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7 -- /bin/sh
apk add curl jq

VAULT_ADDR=http://vault:8200
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
TOKEN=$(curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "test"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')

# Check read
curl --header "X-Vault-Token:s.ajmSRrpD0cZYG2jCqOD1lcQg" $VAULT_ADDR/v1/otus/otus-ro/config
curl --header "X-Vault-Token:s.ajmSRrpD0cZYG2jCqOD1lcQg" $VAULT_ADDR/v1/otus/otus-rw/config

# Check write
curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:s.ajmSRrpD0cZYG2jCqOD1lcQg" $VAULT_ADDR/v1/otus/otus-ro/config
curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:s.ajmSRrpD0cZYG2jCqOD1lcQg" $VAULT_ADDR/v1/otus/otus-rw/config
curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token:s.ajmSRrpD0cZYG2jCqOD1lcQg" $VAULT_ADDR/v1/otus/otus-rw/config1

## Auth via k8s
git clone https://github.com/hashicorp/vault-guides.git
cd vault-guides/identity/vault-agent-k8s-demo

# Create a ConfigMap, example-vault-agent-config
kubectl create configmap example-vault-agent-config --from-file=configs-k8s/
# View the created ConfigMap
kubectl get configmap example-vault-agent-config -o yaml
# Finally, create vault-agent-example Pod
kubectl apply -f example-k8s-spec.yaml --record


# Enable PKI Secrets
kubectl exec -it vault-0 -- vault secrets enable pki
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
kubectl exec -it vault-0 -- vault write -field=certificate pki/root/generate/internal \
  common_name="exmaple.ru" ttl=87600h > CA_cert.crt

# Gen URLs for CRL
kubectl exec -it vault-0 -- vault write pki/config/urls \
issuing_certificates="http://vault:8200/v1/pki/ca" \
crl_distribution_points="http://vault:8200/v1/pki/crl"

# Generate intermediate cert
kubectl exec -it vault-0 -- vault secrets enable --path=pki_int pki
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki_int
kubectl exec -it vault-0 -- vault write -format=json pki_int/intermediate/generate/internal \
common_name="example.ru Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr

# Write intermediate cert to Vault
kubectl cp pki_intermediate.csr vault-0:./tmp/
kubectl exec -it vault-0 -- vault write -format=json pki/root/sign-intermediate \
csr=@/tmp/pki_intermediate.csr \
format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > intermediate.cert.pem
kubectl cp intermediate.cert.pem vault-0:./tmp/
kubectl exec -it vault-0 -- vault write --force pki_int/intermediate/set-signed \
certificate=@/tmp/intermediate.cert.pem

# Create role
kubectl exec -it vault-0 -- vault write pki_int/roles/example-dot-ru \
allowed_domains="example.ru" allow_subdomains=true
 max_ttl="720h"

# Create the Certificate
kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru \
common_name="gitlab.example.ru" ttl="24h"

# Revoke the Certificate
kubectl exec -it vault-0 -- vault write pki_int/revoke \
serial_number="04:5f:bf:3c:5c:6d:5c:fd:e3:71:80:98:9a:f5:fe:fe:0e:41:b6:02"
