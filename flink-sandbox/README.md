# Overview

This sandbox sets up a CP Kafka cluster and a CP Flink cluster in Kubernetes.
The example was tested with minikube.

`confluent-platform.yaml` deploys 
- 1 KRaft Controller
- 3 Brokers
- 1 Schema Registry instance
- 1 Connect instance 
  
This lab derives from  
- https://docs.confluent.io/cp-flink/current/get-started/get-started-statement.html
- https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/quickstart-deploy/kraft-quickstart


# Start a Flink and Kafka Cluster

__Note:__ be sure to upgrade to the latest Confluent CLI before beginning. You've been warned!


```
brew install confluentinc/tap/cli
```

Create a minikube environment.

```
minikube start --cpus=8 --disk-size=50g --memory=16384
```

Install cert. manager.

```
kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.18.2/cert-manager.yaml
```

Install the Confluent Helm repo, the Flink K8s operator, the Confluent Manager 
for Flink and the CFK operator

```
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update
helm upgrade --install --version "~1.140.0" cp-flink-kubernetes-operator confluentinc/flink-kubernetes-operator --set image.pullPolicy=IfNotPresent
helm upgrade --install cmf --version "~2.3.0" confluentinc/confluent-manager-for-apache-flink --set encryption.enabled=false --set image.pullPolicy=IfNotPresent
helm upgrade --install operator confluentinc/confluent-for-kubernetes --set image.pullPolicy=IfNotPresent
```

_Wait for the new pods to start running_.

```
wrmay@H3X1M9JRWG flink-sandbox % kubectl get pods
NAME                                                READY   STATUS    RESTARTS   AGE
confluent-manager-for-apache-flink-cc5cd65c-xtzx7   1/1     Running   0          4m27s
confluent-operator-698fdcdf74-gvbtt                 1/1     Running   0          4m15s
flink-kubernetes-operator-784987f745-p9cs4          2/2     Running   0          4m44s
```

 Deploy Confluent Platform 

 ```
 kubectl apply -f confluent-platform.yaml
 ```

_Wait for everything to come up cleanly_

```
wrmay@H3X1M9JRWG flink-sandbox % kubectl get pods
NAME                                                READY   STATUS    RESTARTS        AGE
confluent-manager-for-apache-flink-cc5cd65c-xtzx7   1/1     Running   0               12m
confluent-operator-698fdcdf74-gvbtt                 1/1     Running   0               12m
connect-0                                           1/1     Running   1 (4m28s ago)   6m56s
controlcenter-0                                     3/3     Running   0               6m56s
flink-kubernetes-operator-784987f745-p9cs4          2/2     Running   0               12m
kafka-0                                             1/1     Running   0               4m26s
kafka-1                                             1/1     Running   0               4m26s
kafka-2                                             1/1     Running   0               4m26s
kraftcontroller-0                                   1/1     Running   0               6m56s
schemaregistry-0                                    1/1     Running   0               3m41s
```

 Once everything has come up you can access the control center at 
 http://localhost:9021 , but first, you must forward the port.

 ```
  kubectl port-forward controlcenter-0 9021:9021 &
 ```

# Set up the Card Event Generator 


Add the required configuration to the cluster as config maps

```
kubectl create configmap cardfraud-env --from-env-file=./card-event-generator/env.properties
kubectl create configmap cardfraud-transaction-schema --from-file=schema=./card-event-generator/card.avsc
```

Set up the topic and the schema for the topic

```
kubectl apply -f card-event-generator/setup.yaml
```

Build the card-event-generator image inside of the minikube environment.

```
eval $(minikube docker-env)
docker build -t event-generator:dev .
```
