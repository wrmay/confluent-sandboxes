__Note:__ be sure to upgrade to the latest Confluent CLI before beginning. You've been warned!

Based on https://docs.confluent.io/cp-flink/current/get-started/get-started-statement.html
and https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/quickstart-deploy/kraft-quickstart


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

Install the Confluent Helm repo, the Flink K8s operator and the 
Confluent Manager for Flink (and the one for Confluent).

```
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update
helm upgrade --install --version "~1.140.0" cp-flink-kubernetes-operator confluentinc/flink-kubernetes-operator --set image.pullPolicy=IfNotPresent
helm upgrade --install cmf --version "~2.3.0" confluentinc/confluent-manager-for-apache-flink --set encryption.enabled=false --set image.pullPolicy=IfNotPresent
helm upgrade --install operator confluentinc/confluent-for-kubernetes --set image.pullPolicy=IfNotPresent
```

_Wait for the new pods to start running_.

----------- SKIP ----------
Port forward the CMF service so it can be accessed locally.  Set 
CONFLUENT_CMF_URL to point to it.
```
kubectl port-forward svc/cmf-service 8080:80&
export CONFLUENT_CMF_URL=http://localhost:8080 
```

Create a Flink environment
```
confluent flink environment create test --kubernetes-namespace default
Handling connection for 8080
+--------------------------------+--------------------------------+
| Name                           | test                           |
| Kubernetes Namespace           | default                        |
| Created Time                   | 2026-05-26 16:50:20.598176     |
|                                | +0000 UTC                      |
| Updated Time                   | 2026-05-26 16:50:20.598176833  |
|                                | +0000 UTC                      |
| Flink Application Defaults     | null                           |
| Flink Compute Pool Defaults    | null                           |
| Detached Statement Defaults    | null                           |
| Interactive Statement Defaults | null                           |
+--------------------------------+--------------------------------+
```
 and create a compute pool

 ```
confluent flink compute-pool create compute-pool.json --environment test
Handling connection for 8080
+---------------+--------------------------+
| Creation Time | 2026-05-26T16:52:17.748Z |
| Name          | pool                     |
| Type          | DEDICATED                |
| Phase         | DEDICATED                |
+---------------+--------------------------+
----------- END SKIP ----------

 ```

 Deploy Confluent Platform 
 ```
 kubectl apply -f confluent-platform.yaml
 ```

 Once everything has come up you can access the control center at 
 http://localhost:9021 , but first, you must forward the port.

 ```
  kubectl port-forward controlcenter-0 9021:9021 &
 ```

