
Generally following https://github.com/confluentinc/confluent-kubernetes-examples/blob/master/hybrid/clusterlink/ccloud-as-destination-cluster/README.md, but I need to create bidirectional cluster links.

```
# from the confluent_kubernetes-examples folder
export TUTORIAL_HOME=`pwd`/hybrid/clusterlink/ccloud-as-destination-cluster
```

```
# set up a minikube cluster
minikube start --cpus=8 --disk-size=50g --memory=16384 --kubernetes-version=v1.29.0
```

The [Basic Setup](https://github.com/confluentinc/confluent-kubernetes-examples/blob/master/hybrid/clusterlink/ccloud-as-destination-cluster/README.md#basic-setup) section wants me to create certs and secrets but I don't 
see those secrets referenced in any yam file in the tutorial directory.  It also 
has instructions for creating the secrets using files that apparently already 
exist (but which I couldn't find) followed by instructions for creating the 
cert and again creating the secret. Not sure what to do with that.  

```
find $TUTORIAL_HOME  -name "*.yaml" | xargs grep ca-pair-sslcerts
# returns nothing
```

Will ignore for now.  make sure to check back when the cluster is actually created.

Install the CFK operator
```
helm repo add confluentinc https://packages.confluent.io/helm
helm upgrade --install operator confluentinc/confluent-for-kubernetes
```

Create a dedicated cluster in CC

Put the confluent CLI on the path
```
export PATH=$PATH:/opt/confluent/confluent-7.5.2/bin
```

Create a global scope key in CC and save the secrets.  Rename the file 
to `basic.txt` and format it as shown below.  __Be sure not to check it in to 
version control!__

```
username=API-KEY
password=API-SECRET
```

In the directory where you saved the above file, create a secret for the 
local cluster to use to access the cluster in CC.

```
kubectl create secret generic restclass-ccloud --from-file=basic.txt=basic.txt
```

TO BE CONTINUED ... see  Glean Conversation "Confluent Kubernetes secret usage"






