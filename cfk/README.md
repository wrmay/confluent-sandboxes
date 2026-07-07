# Environment Setup

Create a minikube environment.

```
minikube start --cpus=8 --disk-size=50g --memory=16384
```

Install the cert-manager for kubernetes.  This is not necessarily needed
for CP but it is needed for Confluent Manager for Apache Flink (cmf) so we
go ahead and install it.

> __Note:__ If you really don't need to install Flink, you can omit the 
> cert-manager as well as the flink-kubernetes-operator and cmf.  The only 
> consequence is an error message displayed on the C3++ UI.

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.3/cert-manager.yaml
```

Wait for all of the related pods to come up. Note that cert-manager is 
installed in the `cert-manager` namespace.

```
wrmay@H3X1M9JRWG cfk % kubectl get pods -n cert-manager
NAME                                     READY   STATUS    RESTARTS   AGE
cert-manager-767885ff64-ttnts            1/1     Running   0          28s
cert-manager-cainjector-d8d76db4-b9j5q   1/1     Running   0          28s
cert-manager-webhook-69d8bdfff-zpddh     1/1     Running   0          28s
```

Install the required CP and Flink operators.

```
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update
helm upgrade --install --version "~1.140.0" cp-flink-kubernetes-operator confluentinc/flink-kubernetes-operator --set image.pullPolicy=IfNotPresent
helm upgrade --install cmf --version "~2.3.0" confluentinc/confluent-manager-for-apache-flink --set encryption.enabled=false --set image.pullPolicy=IfNotPresent
helm upgrade --install  --version "~0.1514.40" operator confluentinc/confluent-for-kubernetes --set image.pullPolicy=IfNotPresent --set image.pullPolicy=IfNotPresent
```

Wait for the new pods to start running.

```
wrmay@H3X1M9JRWG cfk % kubectl get pods
NAME                                                  READY   STATUS    RESTARTS   AGE
confluent-manager-for-apache-flink-86bc4699fb-m7p7j   1/1     Running   0          13m
confluent-operator-7b647f8558-st6c7                   1/1     Running   0          30s
flink-kubernetes-operator-784987f745-9nvlr            2/2     Running   0          13m
```

 Deploy Confluent Platform 

 ```
 kubectl apply -f confluent-platform.yaml
 ```

Wait for the new pods to come up.  _This will take several minutes._
```
wrmay@H3X1M9JRWG cfk % kubectl get pods
NAME                                                  READY   STATUS    RESTARTS      AGE
confluent-manager-for-apache-flink-86bc4699fb-m7p7j   1/1     Running   0             44m
confluent-operator-7b647f8558-st6c7                   1/1     Running   0             31m
connect-0                                             1/1     Running   2 (21m ago)   28m
controlcenter-0                                       3/3     Running   0             28m
flink-kubernetes-operator-784987f745-9nvlr            2/2     Running   0             45m
kafka-0                                               1/1     Running   0             20m
kafka-1                                               1/1     Running   0             20m
kafka-2                                               1/1     Running   0             20m
kafkarestproxy-0                                      1/1     Running   0             20m
kraftcontroller-0                                     1/1     Running   0             28m
schemaregistry-0                                      1/1     Running   0             20m
```

Now, to see control center, you can either do a port-forward via kubectl, or 
use [Telepresence](https://telepresence.io/docs/install/client).   Telepresence 
is and extremely valuable aid to local k8s development. Install it!  If you 
are using a Mac, you can `brew install telepresenceio/telepresence/telepresence-oss`.

Now install the Telepresence traffic manager into your cluster and connect.

```
telepresence helm install
telepresence connect
```

Now you can access control center from your desktop at 
[http://controlcenter.default.svc.cluster.local:9021/](http://controlcenter.default.svc.cluster.local:9021/).
Further, any local programs will run as if they are on the same network as 
the pods in the "default" namespace of your local k8s cluster!






