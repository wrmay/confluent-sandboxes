# Overview

This lab installs Confluent Platform using CFK.  It includes the latest 
Confluent Control Center that integrates with the Flink operator to support 
dynamic provision of Flink compute pools.  Although deploying to a local Minikube 
technically works on a sufficiently big laptop, it is a stretch. It is preferrable 
to deploy it onto a real, multi-node kubernetes cluster.  

See, for example, Create an AKS Cluster](./create_an_aks_cluster.md)

# Minikube Setup

Instructions for setting up a local kubernetes cluster with minikube are given below.
If you already have an environment you can skip this section. 

Create a minikube environment.

```
minikube start --cpus=8 --disk-size=50g --memory=16384
```

For a `podman` based setup on MacOS, first, create the podman machine, then start minikube as shown below

```
podman machine init --cpus 8 --disk-size 50 --memory 16384 --rootful 
podman machine start
minikube start --driver=podman --container-runtime=containerd
```

# Installing Confluent Platform

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

Install the required CP and Flink operators and support for NGINX ingress.  The nginx step can be skipped if you are working locally.

```
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update
helm upgrade --install --version "~1.140.0" cp-flink-kubernetes-operator confluentinc/flink-kubernetes-operator --set image.pullPolicy=IfNotPresent
helm upgrade --install cmf --version "~2.3.0" confluentinc/confluent-manager-for-apache-flink --set encryption.enabled=false --set image.pullPolicy=IfNotPresent
helm upgrade --install  --version "~0.1514.40" operator confluentinc/confluent-for-kubernetes --set image.pullPolicy=IfNotPresent 
helm upgrade --install ingress-nginx ingress-nginx   --repo https://kubernetes.github.io/ingress-nginx   --namespace ingress-nginx --create-namespace
```

Wait for the new pods to start running.

```
wrmay@H3X1M9JRWG cfk % kubectl get pods
NAME                                                  READY   STATUS    RESTARTS   AGE
confluent-manager-for-apache-flink-86bc4699fb-m7p7j   1/1     Running   0          13m
confluent-operator-7b647f8558-st6c7                   1/1     Running   0          30s
flink-kubernetes-operator-784987f745-9nvlr            2/2     Running   0          13m
```

Create a secret to contain the control center password. First, create a file called "cfk/basic.txt" with the following contents (select your own password).

```
admin: PICK-A-PASSWORD,Administrators
```

> __NOTE:__ the space before the password is mandatory! 

Create a k8s secret.
```
kubectl create secret generic controlcenter-ui-users --from-file=basic.txt=./cfk/basic.txt
```



 Deploy Confluent Platform 

 ```
 kubectl apply -f cfk/confluent-platform.yaml
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

# Exposing Confluent Control Center 

> __NOTE__ Skip this if you are using a local environment.  

```
kubectl apply -f cfk/ingress.yaml 
```

To find the external IP ...
```
bash-3.2$ kubectl get service  -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.0.76.184   48.214.187.46   80:32062/TCP,443:31627/TCP   154m
ingress-nginx-controller-admission   ClusterIP      10.0.18.181   <none>          443/TCP                      154m
```
In this case, the external IP is _48.214.187.46_.  You should be able
to access control center with a browser pointing to that address.


# Accessing the Confluent Control Center with Telepresence 
Now, to see control center, you can either do a port-forward via kubectl, or 
use [Telepresence](https://telepresence.io/docs/install/client).   Telepresence 
is an extremely valuable aid to local k8s development. Install it!  If you 
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
