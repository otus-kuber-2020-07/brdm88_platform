##### Выводы команд:

*helm status vault*

```
NAME: vault
LAST DEPLOYED: Thu Jan 28 19:23:00 2021
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://www.vaultproject.io/docs/


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
```
----

###### Init vault
*kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1*

```
Unseal Key 1: rbxaglQwXqwuJZVHmeb2OqiKBrFoiLUEoMNaOEgsMGk=

Initial Root Token: s.ajmSRrpD0cZYG2jCqOD1lcQg

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated master key. Without at least 1 key to
reconstruct the master key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```
----
*kubectl exec -it vault-0 -- vault status*

```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.6.1
Storage Type    consul
Cluster Name    vault-cluster-396eec05
Cluster ID      29c83013-6036-89d6-2d40-c23dbc4db8fc
HA Enabled      true
HA Cluster      https://vault-0.vault-internal:8201
HA Mode         active
```
----
*kubectl exec -it vault-1 -- vault status*
```
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.6.1
Storage Type           consul
Cluster Name           vault-cluster-396eec05
Cluster ID             29c83013-6036-89d6-2d40-c23dbc4db8fc
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.88.2.5:8200

```
----
*kubectl exec -it vault-2 -- vault status*
```
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.6.1
Storage Type           consul
Cluster Name           vault-cluster-396eec05
Cluster ID             29c83013-6036-89d6-2d40-c23dbc4db8fc
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.88.2.5:8200

```
----
* kubectl exec -it vault-0 -- vault login*
```
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                s.ajmSRrpD0cZYG2jCqOD1lcQg
token_accessor       Cv5uCFrFw6nRZIh6pQmygZEw
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```
----
*kubectl exec -it vault-0 -- vault auth list*
```
Path      Type     Accessor               Description
----      ----     --------               -----------
token/    token    auth_token_be630c60    token based credentials
```
----
###### After uploading secrets
*kubectl exec -it vault-0 -- vault read otus/otus-ro/config*
```
Key                 Value
---                 -----
refresh_interval    768h
password            asajkjkahs
username            otus
```
----
*kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config*
```
====== Data ======
Key         Value
---         -----
password    asajkjkahs
username    otus
```
----
###### After adding k8s auth
*kubectl exec -it vault-0 -- vault auth list*
```
Path           Type          Accessor                    Description
----           ----          --------                    -----------
kubernetes/    kubernetes    auth_kubernetes_ef4581d3    n/a
token/         token         auth_token_be630c60         token based credentials
```
----
 * Команда `sed ’s/\x1b\[[0-9;]*m//g’` удаляет коды цветов из текстового вывода.
----
###### Создание политики и роли:
```
kubectl cp otus-policy.hcl vault-0:./tmp
kubectl exec -it vault-0 -- vault policy write otus-policy /tmp/otus-policy.hcl
kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus \
  bound_service_account_names=vault-auth \
  bound_service_account_namespaces=default policies=otus-policy ttl=24h
```

```
Success! Uploaded policy: otus-policy
Success! Data written to: auth/kubernetes/role/otus
```
----
 * Для возможности записи в `otus-rw/config` в файле политики необходимо добваить `update` в `capabilities`.
----


###### Авторизация через k8s.

Содержимое файла `index.html` из контейнера *nginx-container* пода *vault-agent-example*:

*kubectl exec -it vault-agent-example -c nginx-container -- cat /usr/share/nginx/html/index.html*
```
  <html>
  <body>
  <p>Some secrets:</p>
  <ul>
  <li><pre>username: otus</pre></li>
  <li><pre>password: asajkjkahs</pre></li>
  </ul>

  </body>
  </html>
```

###### PKI

###### Создание сертификата
*kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru common_name="gitlab.example.ru" ttl="24h"*
```
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUKbUXhGudPOuz/aXz3iLk5Qa3N2owDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yMTAxMjkwMDIzMTRaFw0yNjAx
MjgwMDIzNDRaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANa7P2nDFs0S
irLj8eus1I+6CpYft5eFEIc2WgZGM+u8eVGY4zDnp+8bn6C14vy5gT/CGvMmFIFl
oly8eK7fR7GLqc+li9k/gK67o56AAbvFMEC7vM9XrIwm6Z2IS5/HXArcw72yy8hP
6lSiizqd34vpvBuoC2UF/+9u2s6D+7qHXI4wNf/6hMDTOGNFuuq4k2ZLg89b5Ja6
ti9FL9RbLtvGzec+k0aTsQK1pKNHQNep1zh5NdektGX7XITLfVCtLemmUX80UUAA
7PQv2XHKqIPMXz7elkEHquJ9Mzx0x/2p4StH1kWZtSjF2NwyjcQ7qFTzkMBMjsfT
nbPqp7PNwIcCAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQU5lz53inc6egZMD9R4d4IxgHIO5wwHwYDVR0jBBgwFoAU
6cc4UIZF3oSBYeJ0yMYJigsOcb8wNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
lRBLVYMGFefD42umupwC38pMmpM2MXYTzrJaJT/mvP7kTBzSqhP720y4Pe68D9yS
BppjhSlJMww3k0d9VXsQDT1TNFnXQ5wI4QPwtTmclS24geiub3xP9l1qrQoSh6MS
OXrXj0OhGcCxV/OfqWoQGumyKTlUNghB9fF1JYM+HKhSo1i/teMcIuahYuLKBwQM
6wsVNsNi32x4HjJvD/nXf9KMmR1SmAobDRTqwFv0XCAYK93LjTQAU09OpA8QYaQB
bZn+1sEnHEx3ITbwk7XKxKH94DBR3DfuKFHnjETOYklnxPABhiBh4sHHg/Jwt26E
fSjvUTdVAPf0F2H/LrCiCg==
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDZzCCAk+gAwIBAgIUBF+/PFxtXP3jcYCYmvX+/g5BtgIwDQYJKoZIhvcNAQEL
BQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUgQXV0aG9yaXR5
MB4XDTIxMDEyOTAwMzcyNloXDTIxMDEzMDAwMzc1NlowHDEaMBgGA1UEAxMRZ2l0
bGFiLmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDY
tXx3J0z9p0Su9gO8L70GvicBIe9865nshYHaObta4RnE0o69GTS4rdyRhtjZhFej
Z/QS7ggL3+v/NCsoQpadFLVW92/EdTZmKRdE9Ou8rBRaWnlpIiG8HGiEYjeKBrg5
/ZH7NBsqIqKy36Sp0VUZUTQXrSQY4bDMyr79oEcKECTBSg3jQxmM0xzm7XF54R9X
S6xtB+ONG5mvAkxqJlLBArA1XLIiHsjFKBq/WhCBNPq0C/+G0fhwCmHcvE1ndvS9
XxXfXJbUYGamzeN2ibZiGkcbsTtb2WBhWYRzmt/jmIyT0HLW+E2xpM/JB4ekZsJi
haayZeYGr6V8+XnrM3sFAgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQU/pPObm0XsAk/8Ood
fR1aBQBuEIcwHwYDVR0jBBgwFoAU5lz53inc6egZMD9R4d4IxgHIO5wwHAYDVR0R
BBUwE4IRZ2l0bGFiLmV4YW1wbGUucnUwDQYJKoZIhvcNAQELBQADggEBAEcwCZro
vU5duff3EFLX2gXSG1w5VE2UAublXU4GHZK3nIB08yBSDKUBO1WDZq//4LgbAOmq
gKH8eeHmc3UGDL+SeDTHjcsgZ5lopV4g/XwKNKitcePCVtZkLA2Y3bfQ/lAmyV1w
BtTB3xcKZWEj70MNvoIA/fd70DAuitcmGaPN7vvsD8w1evx/a1vCE0yEOTERLRzf
UvZT4SOPi+J5LShdrZhMKN9lRdmpzC8FzyfNvKhzA7KVc6vXu1VSdkkwtSRrbWqf
IrFJy2Smvz9hcSjPZzTgMD51GUrEE7XJvNOeIlP2HR7yKNz6mgHRzSLBkIyPXbj5
IWQezi+715+657c=
-----END CERTIFICATE-----
expiration          1611967076
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUKbUXhGudPOuz/aXz3iLk5Qa3N2owDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yMTAxMjkwMDIzMTRaFw0yNjAx
MjgwMDIzNDRaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANa7P2nDFs0S
irLj8eus1I+6CpYft5eFEIc2WgZGM+u8eVGY4zDnp+8bn6C14vy5gT/CGvMmFIFl
oly8eK7fR7GLqc+li9k/gK67o56AAbvFMEC7vM9XrIwm6Z2IS5/HXArcw72yy8hP
6lSiizqd34vpvBuoC2UF/+9u2s6D+7qHXI4wNf/6hMDTOGNFuuq4k2ZLg89b5Ja6
ti9FL9RbLtvGzec+k0aTsQK1pKNHQNep1zh5NdektGX7XITLfVCtLemmUX80UUAA
7PQv2XHKqIPMXz7elkEHquJ9Mzx0x/2p4StH1kWZtSjF2NwyjcQ7qFTzkMBMjsfT
nbPqp7PNwIcCAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQU5lz53inc6egZMD9R4d4IxgHIO5wwHwYDVR0jBBgwFoAU
6cc4UIZF3oSBYeJ0yMYJigsOcb8wNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
lRBLVYMGFefD42umupwC38pMmpM2MXYTzrJaJT/mvP7kTBzSqhP720y4Pe68D9yS
BppjhSlJMww3k0d9VXsQDT1TNFnXQ5wI4QPwtTmclS24geiub3xP9l1qrQoSh6MS
OXrXj0OhGcCxV/OfqWoQGumyKTlUNghB9fF1JYM+HKhSo1i/teMcIuahYuLKBwQM
6wsVNsNi32x4HjJvD/nXf9KMmR1SmAobDRTqwFv0XCAYK93LjTQAU09OpA8QYaQB
bZn+1sEnHEx3ITbwk7XKxKH94DBR3DfuKFHnjETOYklnxPABhiBh4sHHg/Jwt26E
fSjvUTdVAPf0F2H/LrCiCg==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEA2LV8dydM/adErvYDvC+9Br4nASHvfOuZ7IWB2jm7WuEZxNKO
vRk0uK3ckYbY2YRXo2f0Eu4IC9/r/zQrKEKWnRS1VvdvxHU2ZikXRPTrvKwUWlp5
aSIhvBxohGI3iga4Of2R+zQbKiKist+kqdFVGVE0F60kGOGwzMq+/aBHChAkwUoN
40MZjNMc5u1xeeEfV0usbQfjjRuZrwJMaiZSwQKwNVyyIh7IxSgav1oQgTT6tAv/
htH4cAph3LxNZ3b0vV8V31yW1GBmps3jdom2YhpHG7E7W9lgYVmEc5rf45iMk9By
1vhNsaTPyQeHpGbCYoWmsmXmBq+lfPl56zN7BQIDAQABAoIBAC+YnL+m2BgV9tXe
nq9kZMXoWbS7+Vecf3AdWonNiELLkddSz5rkwFmXhgxIa7RKht0S5d6KfSXuhmzE
zn3HMkFJ3RI+wkOJ4urJN50jlesYeFfn6yaWIoaoTqRU1hHwq+HAuaFMrnKwrL9Q
s1/A5EntNd3FX1o/p48zMIOQAkpJHdVlmegY5rR4zP5et9MwTXpXdriaQn/04lg+
IaBckAztPAbyD/6Jkp0utjp1Z0pXd0XDW3Lx3DkOeSJq/FDMQFIB6Eaw1I8ZBY9C
fEkXjPzcRrxVl9JI+IZhWF2oPjWI7JITmLTudvQIT7+uGsM9YLRhMAoXUyOve346
6jDSAMECgYEA4Lh++3XdZ/+9KHTvH8FoyhuDFW/u4wwDLrK8N6zhp+BhgxLXDQOZ
MKX2ravT+5O5ocIUHj2VgcXjgC5RA7m5CsHSOVd9NRYwwRdRWWCp6SU20SGC4nYd
50XSL1IO3fcBVCGyalyrdjlI3yY5t+gXBsubQMUAxM24kwfqDn+cO10CgYEA9t+B
j3Zq8ZbFCrEHfi9qRVJ18N+y924TgPvEbefOmiIFSjpseuLy/Pxqz8Nj5zBOG9lX
pkT64vXMNZN0YXqnF+9YdhPShMfwmrTewd4IGf3MvRJT1e3vWxkBZZURk5/YYjAG
SzLIaku7PKZmL+Tb88Jri/cCpiqnn1tMzn0Na8kCgYBML+DFSjmNR9QOwk5L+tuX
Ieq4OuHH0kvF6k0Lpy4+J0GIGbwVKnImXy4ZxVayRWw7HjyJ4CEvBTNTQuCunanR
rtKiJDpL5EEVRd2Lqs0QQVCraGwicR9ESJSw/GYT9OlbZ61AiDiNdXByT1hkNGiS
Ijd5pxDSqFh6aMV+st759QKBgFCHg/nKRQRdjBT6vlj5Go9WYMacEgMIUzBl8CNx
1EEPC+60tCI52c2QgT8Ym4QUi8Yl1aOVKMnUKDLp0LLjkZILLy4FNUy+88tjaK6Q
wM/JrHmYeuRz4voyY/RA9iTTpYAR7lulSx7xaThVh0vkOaOALhjQEHsnutoOrDVH
MZORAoGATsZ7Guvg1aaBEPRpCjevNRXAU9NRPImWX/K5Az5Nwrx3RknX6ACCgpQ7
K6BD8ffwcTM8DSQXN4ejf+0Vi/uPaA6wBwZU3p3lO4xZ5Xi97wIEMo3orhL8ZhfY
B8ngoSwre0U81GvMuuG+4pdTpouU0AMxBe77I3NCG4OeChcmFm8=
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       04:5f:bf:3c:5c:6d:5c:fd:e3:71:80:98:9a:f5:fe:fe:0e:41:b6:02
```
----
###### Отзыв сертификата
*kubectl exec -it vault-0 -- vault write pki_int/revoke serial_number="04:5f:bf:3c:5c:6d:5c:fd:e3:71:80:98:9a:f5:fe:fe:0e:41:b6:02"*
```
Key                        Value
---                        -----
revocation_time            1611880789
revocation_time_rfc3339    2021-01-29T00:39:49.120441756Z
```
