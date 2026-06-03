# CFK 3.2 + CP 7.9 on minikube to Confluent Cloud Dedicated: bidirectional cluster linking with outbound-only connectivity from minikube

This version replaces the earlier network model. It is written for the case where the minikube cluster represents on-prem and must not accept inbound broker connections. In this pattern, the Confluent Cloud side is the `Inbound` half of the bidirectional pair, the minikube side is the `Outbound` half, and the Cloud-side CR must be created first.

In CFK, a bidirectional link is represented as two `ClusterLink` custom resources that share the same logical `spec.name`, and both must set `sourceInitiatedLink.linkMode: Bidirectional`.

This is the right shape if you want the resulting link to support failover, failback, and `truncate-and-restore`, because `truncate-and-restore` is available only on bidirectional links and only in KRaft mode.

Use a patched CP 7.9 build such as 7.9.5 for this lab. Confluent warns not to use `truncate-and-restore` on CP 7.9.0 through 7.9.2 if the affected topics use Tiered Storage; 7.9.3 and later mitigate that issue.

## What this tutorial builds

You will create:

- one local CFK-managed Kafka cluster on minikube running CP 7.9 in KRaft mode
- one `KafkaRestClass` for the local cluster
- one `KafkaRestClass` that points to the Dedicated Confluent Cloud cluster
- one Cloud-side inbound bidirectional cluster link object created with the Confluent CLI or Confluent Cloud REST API
- one minikube-side `Outbound` bidirectional `ClusterLink` CR

The important consequence is this: all broker connectivity is initiated from minikube. The Cloud-side inbound CR does not carry bootstrap, SASL, or TLS connection settings; those live on the minikube outbound CR because minikube is the side that dials out to Confluent Cloud.

## Secret and credential map

Keep the secrets separate so it is obvious where each one is used.

### 1. `password-encoder-secret`

Used by: the local `Kafka` CR only.

Why: CFK requires a password encoder on each Kafka cluster participating in bidirectional Cluster Linking so that sensitive link configuration can be encrypted.

Expected file in the secret: `password-encoder.txt` containing `password=...`.

### 2. `ccloud-rest-credential`

Used by: the Cloud `KafkaRestClass` only.

Why: CFK manages the Cloud-side cluster-link object through Admin REST, and client-side basic auth in CFK expects a `basic.txt` file in `username=<username> password=<password>` format.

### 3. `ccloud-link-jaas`

Used by: the minikube outbound `ClusterLink` CR only.

Why: this is the Kafka API key and secret the minikube brokers use when they open the outbound SASL/PLAIN connection to the Confluent Cloud brokers.

Expected file in the secret: `plain-jaas.conf` containing a `sasl.jaas.config=...` line.

### 4. `ccloud-tls`

Used by: the Cloud `KafkaRestClass` and the minikube outbound `ClusterLink` CR.

Why: ClusterLink and Admin REST TLS secrets must use PEM material in CFK. The Confluent Cloud examples commonly create a secret with `fullchain.pem` and `cacerts.pem` after extracting the server and CA chain from the Cloud endpoint.

## Step 1: Start minikube and create the namespace

What you are doing: creating the local Kubernetes environment that CFK will manage.

Why: keeping everything in a dedicated namespace makes teardown and troubleshooting easier.

```bash
minikube start --cpus=4 --memory=16384 --disk-size=40g
kubectl create namespace confluent
kubectl config set-context --current --namespace=confluent
```

## Step 2: Install CFK 3.2

What you are doing: installing the operator that manages the Kafka, KafkaRestClass, and ClusterLink CRs.

Why: bidirectional Cluster Linking support in CFK requires CFK 3.2.0 or later with Confluent Platform 7.5 or later.

```bash
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update

helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes \
  --namespace confluent \
  --version <your-cfk-3.2.x-chart-version>
```

When CFK 3.x manages Confluent Platform 7.x components, add the `platform.confluent.io/use-log4j1=true` annotation on the CRs.

## Step 3: Create the password encoder secret

What you are doing: creating the secret the local Kafka cluster will reference.

Why: the local Kafka cluster participates in the bidirectional link pair, so CFK requires the password encoder secret there to store link credentials safely.

```bash
cat > password-encoder.txt <<'EOF'
password=change-me-123
EOF

kubectl create secret generic password-encoder-secret \
  --from-file=password-encoder.txt=./password-encoder.txt
```

## Step 4: Deploy the local CP 7.9 KRaft cluster

What you are doing: creating a minimal local Kafka cluster on minikube and a local `KafkaRestClass`.

Why: `truncate-and-restore` requires KRaft mode, and CFK requires a `KafkaRestClass` for the participating cluster so it can create and manage cluster links.

This example keeps the local Kafka listener simple and unauthenticated. CFK documents that Confluent Platform components are configured without authentication by default, which makes this acceptable for a local lab focused on Cluster Linking mechanics.

Save as `local-cluster.yaml`:

```yaml
apiVersion: platform.confluent.io/v1beta1
kind: KRaftController
metadata:
  name: kraftcontroller
  namespace: confluent
  annotations:
    platform.confluent.io/use-log4j1: "true"
spec:
  replicas: 1
  dataVolumeCapacity: 10Gi
  image:
    application: confluentinc/cp-server:7.9.5
    init: confluentinc/confluent-init-container:3.2.0
---
apiVersion: platform.confluent.io/v1beta1
kind: Kafka
metadata:
  name: kafka
  namespace: confluent
  annotations:
    platform.confluent.io/use-log4j1: "true"
spec:
  replicas: 3
  dataVolumeCapacity: 10Gi
  image:
    application: confluentinc/cp-server:7.9.5
    init: confluentinc/confluent-init-container:3.2.0
  dependencies:
    kRaftController:
      clusterRef:
        name: kraftcontroller
  passwordEncoder:
    secretRef: password-encoder-secret
---
apiVersion: platform.confluent.io/v1beta1
kind: KafkaRestClass
metadata:
  name: krc-cfk
  namespace: confluent
spec:
  kafkaClusterRef:
    name: kafka
```

> Note: be sure not to reduce the number of replicas.  Later on, the cluster
> linking machinery will try to create a metadata topic with 3 replicas.

Apply it:

```bash
kubectl apply -f local-cluster.yaml
kubectl get kafka,kraftcontroller,kafkarestclass
```

## Step 5: Get the local cluster ID

What you are doing: retrieving the cluster ID of the local Kafka cluster.

Why: for the Cloud-side inbound CR, CFK needs the source cluster ID when the link uses `connectionMode: Inbound`.

```bash
kubectl exec -it kafka-0 -- \
  kafka-cluster cluster-id --bootstrap-server localhost:9092
```

Save it:

```bash
export LOCAL_CLUSTER_ID=<your-local-cluster-id>
```

## Step 6: Gather the Confluent Cloud values

What you are doing: collecting the Cloud cluster ID, bootstrap endpoint, and REST endpoint.

Why: the bootstrap endpoint is used by the minikube outbound CR, and the REST endpoint plus cluster ID are used by the Cloud `KafkaRestClass`.

```bash
confluent kafka cluster describe <CC_CLUSTER_ID>
```

Save:
```bash
export CC_CLUSTER_ID=<lkc-...>
export ENV_ID=<cc environment that contains your cluster>  
export CC_BOOTSTRAP=<pkc-....confluent.cloud:9092>
export CC_REST_ENDPOINT=<https://pkc-....confluent.cloud:443>
```

If the Confluent CLI prints the Kafka endpoint with a `SASL_SSL://` prefix, remove that prefix when you use it as the bootstrap endpoint.

## Step 7: Create the Cloud-facing secrets

### 7a. Create the REST API credentials and kubernetes secret 


What you are doing: creating the secret the Cloud `KafkaRestClass` will use for Admin REST.

Why: this credential is for CFK management traffic to the Cloud REST endpoint. It is not the broker credential used by Cluster Linking itself.


```bash
confluent iam service-account create link-admin --description "Service account for Kafka REST access to Dedicated cluster"
```

Save to an environment variable

```bash
export LINK_ADMIN_SA_ID=<sa-id>
```

Bind the ClusterAdminRole to the service account

```bash
confluent iam rbac role-binding create --principal User:$LINK_ADMIN_SA_ID \
   --role CloudClusterAdmin --environment $CC_ENV_ID --cloud-cluster $CC_CLUSTER_ID
```

Create an API KEY for the service account 
```bash
confluent api-key create --service-account $LINK_ADMIN_SA_ID  --resource $CC_CLUSTER_ID
```

create `ccloud-rest-basic.txt` with the following contents

```
username=<CC_REST_API_KEY>
password=<CC_REST_API_SECRET>
```

create the secret

```
kubectl create secret generic ccloud-rest-credential --from-file=basic.txt=./ccloud-rest-basic.txt
```

### 7b. Create the Cloud broker credential secret

What you are doing: creating the Kafka API key and secret that the minikube brokers will use to authenticate to Confluent Cloud.

Why: all broker connections originate from minikube in this design, so this secret is referenced only by the minikube outbound CR. For a lab, `confluent api-key create --resource ...` is the quickest path; the private-to-public documentation notes that this is convenient for development/testing but not the least-privilege production pattern.

```bash
confluent api-key create --resource $CC_CLUSTER_ID
```

Create the JAAS file and secret:

```bash
cat > ccloud-link-jaas.conf <<'EOF'
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<CC_LINK_API_KEY>" password="<CC_LINK_API_SECRET>";
EOF

kubectl create secret generic ccloud-link-jaas \
  --from-file=plain-jaas.conf=./ccloud-link-jaas.conf
```

### 7c. Create the Cloud TLS secret

What you are doing: creating the PEM secret used to verify the Confluent Cloud TLS endpoint.

Why: CFK ClusterLink TLS configuration uses PEM-formatted secrets, and the Confluent Cloud hybrid examples commonly store the returned server chain in `fullchain.pem` and the CA chain in `cacerts.pem`.

Fetch the certificates from the Cloud endpoint:

```bash
openssl s_client -showcerts -servername <cloud-rest-hostname> \
  -connect <cloud-rest-hostname>:443 < /dev/null
```

Save the server chain as `fullchain.pem` and the CA chain as `cacerts.pem`. 
Be sure to include the BEGIN CERTIFICATE / END CERTIFICATE lines.  The 
first cert should be placed in `fullchain.pem` and the second in `cacerts.pem`.

Create the secret:

```bash
kubectl create secret generic ccloud-tls \
  --from-file=fullchain.pem=./fullchain.pem \
  --from-file=cacerts.pem=./cacerts.pem
```

## Step 8: Create the Cloud KafkaRestClass

What you are doing: defining a `KafkaRestClass` that represents the Confluent Cloud cluster to the minikube-side CFK resources.

Why: the Cloud-side cluster link object itself will be created with the Confluent CLI or the Confluent Cloud REST API, not by CFK. This `KafkaRestClass` is kept so the minikube-side CFK `ClusterLink` can consistently refer to the Confluent Cloud cluster.

Save as `krc-cloud.yaml`:

```yaml
apiVersion: platform.confluent.io/v1beta1
kind: KafkaRestClass
metadata:
  name: krc-cloud
  namespace: confluent
spec:
  kafkaRest:
    endpoint: <CC_REST_ENDPOINT>
    kafkaClusterID: <CC_CLUSTER_ID>
    authentication:
      type: basic
      basic:
        secretRef: ccloud-rest-credential
    tls:
      secretRef: ccloud-tls
```

Apply it:

```bash
kubectl apply -f krc-cloud.yaml
kubectl get kafkarestclass
```

## Step 9: Create the Cloud-side inbound link object first

What you are doing: creating the Confluent Cloud half of the bidirectional pair.

Why: because the Cloud side is Confluent Cloud, this half must be created with the Confluent CLI or the Confluent Cloud REST API rather than with a CFK CR. For this private-to-public pattern, the Cloud side is the `Inbound` half, and it must be created first. Inbound mode on the destination side requires the source cluster ID but does not carry bootstrap, SASL, or TLS connection details.

Create a config file for the Cloud-side link object:

```bash
cat > cloud-inbound.config <<'EOF'
link.mode=BIDIRECTIONAL
connection.mode=INBOUND
EOF
```

Create the inbound half on Confluent Cloud with the Confluent CLI:

```bash
confluent kafka link create hybrid-bidir-link --cluster $CC_CLUSTER_ID \
  --remote-cluster $LOCAL_CLUSTER_ID --config cloud-inbound.config
```

What this command means:

- `hybrid-bidir-link` is the logical link name and must match the name used on the minikube-side CFK `ClusterLink`.
- `--cluster $CC_CLUSTER_ID` targets the Confluent Cloud cluster, which is the destination for this inbound half.
- `--remote-cluster $LOCAL_CLUSTER_ID` identifies the minikube Kafka cluster as the remote side of the pair.
- `link.mode=BIDIRECTIONAL` and `connection.mode=INBOUND` tell Confluent Cloud to create the inbound side of a bidirectional source-initiated relationship.

Optional REST API equivalent (_UNVERIFIED_):

```bash
curl -u <CLOUD_API_KEY>:<CLOUD_API_SECRET> \
  -X POST \
  -H 'Content-Type: application/json' \
  "$CC_REST_ENDPOINT/kafka/v3/clusters/$CC_CLUSTER_ID/links?link_name=hybrid-bidir-link" \
  -d '{
    "source_cluster_id": "'$LOCAL_CLUSTER_ID'",
    "configs": [
      {"name": "link.mode", "value": "BIDIRECTIONAL"},
      {"name": "connection.mode", "value": "INBOUND"}
    ]
  }'
```

Important notes:

- The inbound side must be created before the minikube outbound side.
- This Cloud-side object does not need bootstrap servers or broker credentials; those are supplied on the minikube outbound side.
- If you later add link-level features such as consumer offset sync, add those configs to the Cloud-side link object because they apply to what lands on Confluent Cloud.

## Step 10: Create the minikube-side outbound CR second

What you are doing: creating the local half of the bidirectional pair.

Why: this is the CR that actually opens the broker connection to Confluent Cloud, so it carries the Cloud bootstrap endpoint, Cloud broker credential secret, and Cloud TLS secret.

Save as `minikube-outbound.yaml`:

```yaml
apiVersion: platform.confluent.io/v1beta1
kind: ClusterLink
metadata:
  name: minikube-outbound
  namespace: confluent
spec:
  name: hybrid-bidir-link
  sourceInitiatedLink:
    linkMode: Bidirectional
    connectionMode: Outbound
  sourceKafkaCluster:
    bootstrapEndpoint: <CC_BOOTSTRAP>
    kafkaRestClassRef:
      name: krc-cloud
    authentication:
      type: plain
      jaasConfigPassThrough:
        secretRef: ccloud-link-jaas
    tls:
      enabled: true
      secretRef: ccloud-tls
  destinationKafkaCluster:
    kafkaRestClassRef:
      name: krc-cfk
  mirrorTopics:
    - name: from-cloud
      direction: toDestination
```

What this CR means:

- `connectionMode: Outbound` makes minikube the side that initiates the broker connection.
- `sourceKafkaCluster` points at Confluent Cloud here because this CR is the one that receives Cloud-originated topics into the local cluster.
- `ccloud-link-jaas` is used exactly here, under the remote side that minikube connects to.

Apply it:

```bash
kubectl apply -f minikube-outbound.yaml
```

## Step 11: Verify the link pair

What you are doing: checking both halves of the bidirectional pair: the Confluent Cloud inbound link object and the minikube CFK outbound CR.

Why: the two halves are created through different control planes, so you should verify each side with the tool that owns it.

Verify the Confluent Cloud side:

```bash
confluent kafka link list --cluster $CC_CLUSTER_ID
confluent kafka --cluster $CC_CLUSTER_ID link configuration list hybrid-bidir-link
```

Verify the minikube CFK side:

```bash
kubectl get clusterlink
kubectl describe clusterlink minikube-outbound
```

If the Cloud-side link object and the minikube-side CR do not use the same logical link name, they will not establish as one bidirectional pair.

## Step 12: Validate both directions

What you are doing: creating one source topic on each side and validating replication in both directions.

Why: in CFK bidirectional mode, each CR owns the mirror topics that land on its local side.

Create the local source topic:

```bash
kubectl exec -it kafka-0 -- \
  kafka-topics --bootstrap-server localhost:9092 \
  --create --if-not-exists --topic from-local \
  --partitions 1 --replication-factor 1
```

Create the Cloud source topic:

```bash
confluent kafka topic create from-cloud --cluster $CC_CLUSTER_ID
```

Produce on minikube and consume from Cloud:

```bash
kubectl exec -it kafka-0 -- bash -lc \
  "echo hello-from-local | kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic from-local"

confluent kafka topic consume from-local --cluster $CC_CLUSTER_ID --from-beginning
```

Produce on Cloud and consume locally:

```bash
echo hello-from-cloud | confluent kafka topic produce from-cloud --cluster $CC_CLUSTER_ID

kubectl exec -it kafka-0 -- \
  kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic from-cloud --from-beginning --timeout-ms 20000
```

## Step 13: Why this setup supports truncate-and-restore

This setup supports `truncate-and-restore` because the link is bidirectional and the local Confluent Platform cluster is in KRaft mode.

Operationally, the failback idea is:

1. fail over or promote on the DR side
2. run there for as long as needed
3. when the original side is ready again, run `truncate-and-restore` on the original primary topic so it becomes a mirror of the new primary
4. use the reverse commands to re-establish the original steady-state direction if desired

Remember that `truncate-and-restore` truncates divergent records written to the old primary after failover, so it is a controlled failback operation, not a harmless toggle.

## Step 14: Important notes for this specific topology

- You do not need to expose minikube brokers publicly or create DNS records for the local brokers for this source-initiated design. The older Confluent example notes that DNS setup is required only for destination-based linking, not for source-initiated linking.

- Do not configure ACL sync here. Confluent documents that ACL sync is not supported between Confluent Platform and Confluent Cloud.

- Do not enable consumer group prefixing on a bidirectional link. It is not supported and will fail validation.

- If you create mirror topics outside CFK, CFK will not treat them as desired state and may delete them on reconciliation after restart.

## Troubleshooting checklist

1. The Cloud inbound link object must be created before the minikube outbound CR.

2. The Cloud-side link name and the minikube-side `spec.name` must match exactly.

3. If the minikube outbound CR is failing, check the three Cloud-facing items first:
   - `CC_BOOTSTRAP`
   - `ccloud-link-jaas`
   - `ccloud-tls`

4. If the Cloud inbound link object is not becoming healthy, verify that `LOCAL_CLUSTER_ID` is correct. Inbound mode depends on the source cluster ID to associate the two halves properly.

5. If you later secure the local Kafka listener, you will need to add local-side authentication details as well. For SASL-SSL secured bidirectional links, CFK expects authentication on both sides so it can generate the local and remote JAAS configuration it needs.


---

## Sources

- [.html](https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/private-networking.html)
- [.html](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html)
- [.html](https://docs.confluent.io/operator/current/co-link-clusters.html)
- [Cluster Linking Commands Confluent Platform | Confluent Documentation](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/commands.html)
- [Manage Cluster Linking for Confluent Platform Using Confluent for Kubernetes | Confluent Documentation](https://docs.confluent.io/operator/current/co-link-clusters.html)
- [Setup Topic and Clusterlink in CCLOUD](https://github.com/confluentinc/confluent-kubernetes-examples/blob/master/hybrid/clusterlink/ccloud-as-destination-cluster/README.md)
- [Manage Confluent Admin REST Class for Confluent Platform Using Confluent for Kubernetes | Confluent Documentation](https://docs.confluent.io/operator/current/co-manage-rest-api.html)
- [Configure Authentication for Confluent Platform Components Using Confluent for Kubernetes | Confluent Documentation](https://docs.confluent.io/operator/current/co-authenticate-cp.html)
- [.html](https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/cluster-links-cc.html)
- [Manage Confluent Admin REST Class for Confluent Platform Using Confluent for Kubernetes | Confluent Documentation](https://docs.confluent.io/operator/current/co-manage-rest-api.html)
- [Configure Network Encryption for Confluent Platform Using Confluent for Kubernetes | Confluent Documentation](https://docs.confluent.io/operator/current/co-network-encryption.html)
- [Upgrade Confluent for Kubernetes | Confluent Documentation](https://docs.confluent.io/operator/current/co-upgrade-cfk.html)
- [Configure RBAC for Confluent Platform Using Confluent for Kubernetes | Confluent Documentation](https://docs.confluent.io/operator/current/co-rbac.html)
- [Cluster Linking for Failover and Disaster Recovery on Confluent Cloud | Confluent Documentation](https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/dr-failover.html)