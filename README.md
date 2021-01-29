# brdm88_platform
brdm88 Platform repository


Kubernetes-Storage
==================

##### Базовая часть

Листинг команд, использовавшихся при выполнении данного задания, приведен в файле `commands.sh` в папке *kubernetes-storage*.

В рамках данного задания выполнено следующее:
 - Развернут кластер в *Minikube*, установлен CSI Host Path драйвер (из https://github.com/kubernetes-csi/csi-driver-host-path).
 - Созданы и развернуты манифесты для **StorageClass**, **PersistentVolumeClaim** и **Pod**. Опробована работа с подключенным хранилищем.

----
----


Kubernetes-Vault
================

##### Базовая часть

Выводы ряда команд, оговоренных в методических указаниях, приведены в файле [README.md](kubernetes-vault/README.md) в папке данного ДЗ.

Листинг команд, использованных при выполнении данного задания, приведен в файле `commands.sh` в папке `kubernetes-vault`.

В рамках данного задания выполнено следующее:
 - В кластере в GKE развернуты *Consul* и *Vault*, проведена инициализация.
 - Созданы секреты в Vault
 - Настроена авторизация Kubernetes Vault
 - Опробована передача секретов из Vault в под с Nginx
 - Опробована работа с PKI

В презентации в задании о подключении секрета из Vault в Nginx приведены данные, основанные на устаревшем на сегодняшний день состоянии репозитория https://github.com/hashicorp/vault-guides.
Попытка запустить Pod с конфигурацией, созданной на основе актуального на сегодняшний день состояния ветки master в репозитории, к успеху не привела. В итоге за основу была взят подход к конфигурированию от состояния репозитория "до коммита 23.05.2020 г."


----
----



Kubernetes-Gitops
=================


###### Part 1 – Flux


**Репозиторий с проектом microservices-demo**: https://gitlab.com/brdm88/microservices-demo

Для репозитория настроен CI Pipeline (с ручным запуском), осуществляющий сборку Docker-образов для компонент приложения *microservices-demo*, а также их загрузку на Docker Hub. Для сервиса *cartservice* изменен базовый образ в связи с ошибками сборки (Issue: https://github.com/dotnet/dotnet-docker/issues/2548)


В рамках данного задания выполнено следующее:

 - Проект microservices-demo загружен в репозиторий, созданный на gitlab.com. 
 - Собраны docker-образы и подготовлены helm-чарты для компонент приложения.
 - Создан кластер в GKE из 4-х нод n1-standard-2, подключен аддон *Istio*.
 - В кластере установлены и настроены *Flux* и *Helm operator*.
 - Опробована работа Flux и Helm operator.

 - Проверена корректность работы Flux при обновлении версий образов сервисов в Docker Registry, подтверждено автоматическое обновление тэга образа в манифесте HelmRelease в git-репозитории (на примере сервиса frontend).

 - Если, например, изменить имя Deployment-а в чарте, то *Helm Operator* создаст новый Deployment с новым именем, а старый – удалит. 
Соответствующие выдержки (момента обновления `frontend`) из лога Helm operator приведена ниже.

```
ts=2021-01-26T01:40:27.854839171Z caller=release.go:79 component=release release=frontend targetNamespace=microservices-demo resource=microservices-demo:helmrelease/frontend helmVersion=v3 info="starting sync run"
...
ts=2021-01-26T01:40:28.155552293Z caller=helm.go:69 component=helm version=v3 info="preparing upgrade for frontend" targetNamespace=microservices-demo release=frontend
...
ts=2021-01-26T01:40:28.466683189Z caller=helm.go:69 component=helm version=v3 info="Created a new Deployment called \"frontend-hipster\" in microservices-demo\n" targetNamespace=microservices-demo release=frontend
ts=2021-01-26T01:40:28.472348089Z caller=helm.go:69 component=helm version=v3 info="Looks like there are no changes for Gateway \"frontend-gateway\"" targetNamespace=microservices-demo release=frontend
...
ts=2021-01-26T01:40:28.511047044Z caller=helm.go:69 component=helm version=v3 info="Deleting \"frontend\" in microservices-demo..." targetNamespace=microservices-demo release=frontend
ts=2021-01-26T01:40:28.543269998Z caller=helm.go:69 component=helm version=v3 info="updating status for upgraded release for frontend" targetNamespace=microservices-demo release=frontend
ts=2021-01-26T01:40:28.58663675Z caller=release.go:364 component=release release=frontend targetNamespace=microservices-demo resource=microservices-demo:helmrelease/frontend helmVersion=v3 info="upgrade succeeded" revision=9e2c4cb667f3737e138449888ffec36bba0f84af phase=upgrade
```

 - Созданы манифесты *HelmRelease* для всех компонент приложения microservices-demo. Проверена корректность развертывания соответствующих сущностей в кластере.



###### Part 2 – Istio + Flagger + Canary Deployments

 - В кластер установлен *Istio* с помощью istioctl (предварительно отключен плагин Istio в GKE). Затем развернут *Flagger*.

 - Для NS `microservices-demo` установлен label для встраивания sidecar-контейнера с `istio-proxy` в поды.
 - Поды приложения *microservices-demo* переразвернуты с `istio-proxy`. Доработан чарт сервиса *frontend* c добавлением манифестов для `Gateway` и `VirtualService` для обеспечения внешнего доступа к *frontend*.

 - Создан и опробован манифест **Canary** для сервиса *frontend*. Достигнуто успешное обновление сервиса. Донастроен чарт сервиса *loadgenerator* для его корректной работы.

Вывод команды:` kubectl -n microservices-demo get canary`
```
NAME       STATUS      WEIGHT   LASTTRANSITIONTIME
frontend   Succeeded   0        2021-01-28T10:55:10Z`
```

Вывод команды: `kubectl -n microservices-demo describe canary frontend ` после успешного обновления *frontend*:
```
Name:         frontend
Namespace:    microservices-demo
Labels:       <none>
Annotations:  helm.fluxcd.io/antecedent: microservices-demo:helmrelease/frontend
API Version:  flagger.app/v1beta1
Kind:         Canary
Metadata:
  Creation Timestamp:  2021-01-26T16:53:30Z
  Generation:          4
  Resource Version:    1005301
  Self Link:           /apis/flagger.app/v1beta1/namespaces/microservices-demo/canaries/frontend
  UID:                 08eb8a72-63e3-44da-8e95-53c376118487
Spec:
  Analysis:
    Interval:    1m
    Max Weight:  50
    Metrics:
      Interval:   1m
      Name:       istio_requests_total
      Threshold:  99
    Step Weight:  10
    Threshold:    1
  Provider:       istio
  Service:
    Gateways:
      frontend-gateway
    Hosts:
      *
    Port:         80
    Target Port:  8080
    Traffic Policy:
      Tls:
        Mode:  DISABLE
  Target Ref:
    API Version:  apps/v1
    Kind:         Deployment
    Name:         frontend
Status:
  Canary Weight:  0
  Conditions:
    Last Transition Time:  2021-01-28T10:55:10Z
    Last Update Time:      2021-01-28T10:55:10Z
    Message:               Canary analysis completed successfully, promotion finished.
    Reason:                Succeeded
    Status:                True
    Type:                  Promoted
  Failed Checks:           0
  Iterations:              0
  Last Applied Spec:       85696bb476
  Last Transition Time:    2021-01-28T10:55:10Z
  Phase:                   Succeeded
  Tracked Configs:
Events:
  Type    Reason  Age                From     Message
  ----    ------  ----               ----     -------
  Normal  Synced  12m (x4 over 37h)  flagger  New revision detected! Scaling up frontend.microservices-demo
  Normal  Synced  11m (x4 over 37h)  flagger  Starting canary analysis for frontend.microservices-demo
  Normal  Synced  11m (x3 over 17h)  flagger  Advance frontend.microservices-demo canary weight 10
  Normal  Synced  10m                flagger  Advance frontend.microservices-demo canary weight 20
  Normal  Synced  9m4s               flagger  Advance frontend.microservices-demo canary weight 30
  Normal  Synced  8m4s               flagger  Advance frontend.microservices-demo canary weight 40
  Normal  Synced  7m4s               flagger  Advance frontend.microservices-demo canary weight 50
  Normal  Synced  6m4s               flagger  Copying frontend.microservices-demo template spec to frontend-primary.microservices-demo
  Normal  Synced  5m4s               flagger  Routing all traffic to primary
  Normal  Synced  4m4s               flagger  (combined from similar events): Promotion completed! Scaling down frontend.microservices-demo
```

----
----


Kubernetes-Logging
==================

##### Базовая часть

В рамках данного задания выполнено следующее:
 - В GKE развернут кластер 4-мя нодами в 2-х пулах. Развернуто приложение *Hipster Shop*.

 - В кластере, на нодах из пула infra-pool, развернут EFK-стек посредством Helm. 

 - Развернут *nginx-ingress* (3 реплики на нодах infra-pool) для возможности доступа к Kibana.

 - Развернут *Elasticsearch Exporter* для мониторинга ES (предварительно развернут *Prometheus Operator* из чарта).

 - Проведен эксперимент с выводом из работы нод Elasticsearch. Добавлен dashboard для Elasticsearch (#4358) в Grafana.

 - Для *nginx-ingress* активирован экспорт метрик через соответствующее определение в values.yaml. Добавлен фильтр для преобразования формата логов Nginx в JSON. Добавлен dashboard для nginx-ingress (#9614) в Grafana.

 - В Kibana cоздан Dashboard для визуализации следующих метрик nginx-ingress: общее количество запросов к nginx-ingress, кол-во запросов с различными статусами. Конфигурация выгружена в файл export.ndjson.

 - В кластере развернуты Loki и Promtail, используя Helm. Datasource Loki добавлен в values.yaml для Prometheus Operator.
 
 - Создан dashboard в Grafana, агрегирующий метрики nginx-ingress, а также его логи.

Ниже приложены скриншоты dashboard-ов в *Grafana* и *Kibana*, отражающих некоторые метрики и логи *Nginx-Ingress*.

###### Kibana Dashboard
![Prometheus](kubernetes-logging/screenshots/kibana-dashboard.png)

###### Grafana Dashboard
![Grafana](kubernetes-logging/screenshots/grafana-nginx.png)


----
----


Kubernetes-Monitoring
=====================

##### Базовая часть

В рамках данного задания выполнено следующее:

 - Развернут кластер GKE в Google Cloud с нодами *g1-small*, в кластер перед началом основных работ установлены *Nginx-ingress* и *Cert-Manager* для возможности работы по HTTPS. 

 - В кластер установлен *Prometheus Operator* из чарта с помощью Helm 3. Настроены Ingress-ы для сервисов подсистемы мониторинга.

 - Создан Docker-образ на базе Nginx, отдающий `stub_status`, развернут *Deployment* с тремя репликами (nginx-exporter встроен в поды в качестве sidecar-контейнера). Созданы манифесты для *Service* и *ServiceMonitor*

 - В Grafana развернут Dashboard “Nginx Exporter”.

Манифесты деплоя тестового workload, а также все необходимое для сборки docker-образа, находится в подпапке **nginx-custom**.

Ниже приложены скриншоты страницы target-ов в Prometheus, а также дашборда в Grafana во время запущенного через siege нагрузочного теста сервиса на базе Nginx.

###### Prometheus Targets
![Prometheus](kubernetes-monitoring/screenshots/03-prom-targets.png)

###### Grafana Dashboard
![Grafana](kubernetes-monitoring/screenshots/01-grafana-01.png)
![Grafana](kubernetes-monitoring/screenshots/02-grafana-02.png)


----
----


Kubernetes-Operators
====================

##### Базовая часть

В рамках данного задания выполнено следующее:
 - Развернут кластер в Minikube, созданы манифесты кастомного ресурса для использования MySQL-оператором.
 - Задание выполнялось на версии Kubernetes 1.20, в силу чего структура манифеста CRD была изменена относительно предложенного в задании варианта для возможности работы в `apiVersion: apiextensions.k8s.io/v1`. Добавлены определения обязательности полей.

 - Реализован контроллер на Python для работы оператора. Для проверки работоспособности развернута БД, затем CR был удален и пересоздан - восстановление БД из бэкапа отработало (только в случае с Minikube PV пришлось удалить вручную).
 - Собран Docker-образ с контроллером, и загружен на Docker Hub. Далее, оператор развернут в кластере, после чего проверена работоспособность процессов создания и удаления CR.


----
----


Kubernetes-Templating
=====================

##### Базовая часть

В рамках данного задания выполнено слудующее:
 - С помощью *Terraform* развернут кластер GKE в Google Cloud (файлы конфигурации находятся в подпапке `terraform-gke`)
 - С помощью *Helm 3* установлены Helm-чарты для *nginx-ingress*, *cert-manager*, *chartmuseum*, *harbor*.
 - Для того, чтобы работал *cert-manager*, необходимо дополнительно создать объект `ClusterIssuer`
 - Сконфигурирован Ingress для ChartMuseum. Проведена проверка успешности установки ChartMuseum. Работа с ChartMuseum производится посредством HTTP-запросов.
 - Установлен Harbor и сконфигурирован Ingress для него, проведена проверка успешности установки.

Команды установки чартов находятся в папке `scripts`.

 - Создан чарт для приложения *Hipster Shop*, после чего последнее развернуто в кластере (для проверки доступа через NodePort сервис был открыт соответствующий порт на файерволе GCP). 
Далее, отдельно выделен чарт для компонента *frontend* и добавлен как зависимость к чарту Hipster Shop. Создан манифест для Ingress. Для данного чарта шаблонизированы следующие параметры: число реплик деплоя, тэг образа, порты и тип сервиса. Чарты загружены в установленный экземпляр Harbor (с включенным Chartmuseum).

 - Для компонентов Paymentservice и Shippingservice изучена и произведена установка в кластер с помощью Kubecfg.


----
----

Kubernetes-Volumes
===================

##### Базовая часть

В рамках данного задания развернут локальный кластер Kind, в котором запущен MinIO (StatefulSet и Headless Service). Изучена работа MinIO. Для возможности доступа к MinIO Browser из-за пределов кластера дополнительно создается Ingress.


##### Дополнительные задания

Манифест MinIO StatefulSet доработан для передачи значений переменных окружения через секрет Kubernetes. Объект *Secret* создается с помощью команды `kubectl create secret generic minio-secret --from-literal=MINIO_ACCESS_KEY=minio --from-literal=MINIO_SECRET_KEY=minio123 -o yaml > minio-secret.yaml`.



----
----

Kubernetes-Networks
===================

##### Базовая часть

1) В рамках данного задания реализованы манифесты Deployment с probes и Service для макетного pod-a из первой работы. Изучена работа ClusterIP. На локальном кластере Minikube включен режим балансировки IPVS, перезапущен kube-proxy и очищены неиспользуемые правила iptables. На ноде minikube установлены ipvsadm и ipset, исследована работа IPVS.

2) В локальном кластере развернут MetalLB. Развернут Service типа LoadBalancer.

3) В локальном кластере развернут Ingress-контроллер на базе Nginx. Запущен headless service для макетного веб-сервиса и правило Ingress для доступа к нему.


##### Дополнительные задания

* Реализован манифест для сервиса (точнее, двух, для TCP и UDP) типа LoadBalancer для доступа к CoreDNS из-за пределов кластера.

* Организован доступ к Kubernetes Dashboard (был установлен из отдельного репозитория, а не как аддон Minikube) через nginx-ingress. Для того, чтобы доступ был возможен по URL *https://<ip_of_nginx_ingress>/dashboard* (без '/' в конце), пришлось добавить в конфигурацию дополнительные правила `rewrite` чере аннотацию `nginx.ingress.kubernetes.io/configuration-snippet` в манифесте *Ingress*. Для возможности полноценного использования Dashboard добавляется *ServiceAccount* с ролью *cluster-admin* в namespace *kubernetes-dashboard*.

* Реализованы 2 набора манифестов (*Deployment, Service, Ingress*): для "текущей" версии приложения и для "обновленной", разворачиваемой канареечным деплоем. В манифесте *Ingress* для "канареечной" версии конфигурация производится с помощью аннотаций. Перенаправление запросов производится в зависимости от значения HTTP-заголовка `X-IsCanary`. Доступ к макетному сервису организован по URL *http://ingress.local/canary* (при этом имя *ingress.local* должно разрешаться в IP-адрес Nginx-Ingress). Подобный подход был применен в силу того, что Canary в Nginx-Ingress не работает без указания имени хоста.



----
----

Kubernetes-Security
===================

##### Базовая часть

В рамках данного задания реализованы манифесты для создания аккаунтов (сущность ServiceAccount) и предоставления им определенных прав в кластере (сущности ClusterRole, ClusterRoleBinding, Role, RoleBinding).



----
----

Kubernetes-Controllers
======================

##### Базовая часть

В рамках данного задания предварительно развернут локальный кластер Kind из 3-х master и 3-х worker нод. Изучена работа ReplicaSet на примере сервиса frontend от Hipster Shop. При обновлении ReplicaSet (применении манифеста с новой версией в шаблоне) запущенные поды не обновились, версия образа обновилась только при пересоздании подов. Такая особенность работы ReplicaSet обусловлена тем, что ReplicaSet, как и ReplicationController, не проверяет соответствие запущенных подоб шаблону, а только лишь следит за количеством запущенных подов.
Изучена работа Deployment, механизм обновления Rolling Update и работа Probes.


##### Дополнительные задания

* Реализованы сценарии развертывания **Blue-Green** и **Reverse Rolling Update** для сервиса frontend.
* Реализован манифест **DaemonSet** для развертывания *Node Exporter* на всех нодах кластера (включая master-ноды). Развертывание подов DaemonSet-а на master-нодах обеспечивается указанием в манифесте `tolerations` в шаблоне пода (в контексте данного задания в кластере Kind Taints присутствуют только на master-нодах, поэтому в секции Tolerations достаточно будет обойтись `operator: Exists`).



----
----

Kubernetes-Intro
================

##### Базовая часть

В рамках выполнения данного задания подготовлено локальное окружение для работы с Kubernetes. Развернут локальный кластер с помощью Minikube. Опробовано самовосстановление подов в namespace kube-system после их удаления.

* Поды системных компонент Kubernetes (`kube-apiserver, kube-controller-manager, kube-scheduler, etcd`) являются **static pods** и управляются непосредственно kubelet-ом на ноде, соответственно последний следит за их состоянием и восстанавливает после удаления. Манифесты static pod-ов находятся на ноде по пути `/etc/kubernetes/manifests`

* В свою очередь, поды core-dns и kube-proxy управляются уже механизмами кластера Kubernetes (описаны соответственно как Deployment и DaemonSet в NS kube-system) и восстанавливаются в силу того, что kube-controller-manager следит за состоянием кластера и при любых «непредвиденных» изменениях стремится привести его к состоянию, описанному в etcd.


Написан Dockerfile макетного веб-сервиса и манифест Pod для запуска данного сервиса в кластере, pod запущен в кластере Minikube.


##### Дополнительные задания

В локальном кластере запущен сервис frontend от Hipster Shop. Выяснена и исправлена причина его незапуска. 
В изначальной конфигурации frontend не запускался по причине того, что не были заданы необходимые переменные окружения.
Например, в выводе команды `kubectl logs` для этого пода имеем:  `panic: environment variable "PRODUCT_CATALOG_SERVICE_ADDR" not set`, подобным образом можно выявить и другие недостающие значения переменных. 
В исправленном манифесте *frontend-pod-healthy.yaml*, при применении которого под запускается, заданы значения необходимых переменных.

