# Overview and Concepts 

Cluster links allow data to be copied between topics in two different clusters.  
For a given topic data will only flow in one direction at a time.  The 
direction of data flow can be different for different topics or, for a 
single topic at two different times.

A _cluster_link_ is essentially just a connection between two clusters. It 
contains the information required to establish a connection including 
bootstrap servers and credentials for authentication.  

A _mirror_ is an instruction to replicate messages in one direction or 
the other.  When a mirror is set up, only one side, the source, is writable.
The target side is read only and can be considered a warm standby.  

Options on cluster links include
* synchronizing ACLs 
* synchronizing consumer group offsets for all or a subset of groups

## Cluster Linking Types

### Basic 
A basic cluster link is unidirectional and is configured on the destination 
cluster. The link is configured with the information needed for the destination 
cluster to connect to the source cluster (bootstrap servers, etc.).

## Bidirectional
A Bidirectional cluster link, unsurprisingly, allows data to flow in both 
directions. A bidirectional link  must be configured on both clusters using the same link name.
Via the [connection.mode](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html#configuration-options) 
property, you can specify that one side always initiates the connection 
(`connection.mode=OUTBOUND`) and the other side receives it (`connection.mode=INBOUND`), 
which is useful, for example, when connecting an on-premise cluster to 
Confluent Cloud.  The need to allow inbound connection to an on-prem cluster 
can be avoided by setting the on-prem link's  `link.mode` to `OUTBOUND` and the 
Confluent Cloud side link to `INBOUND`.

It's also possible to configure both sides as `OUTBOUND`.  In this case, each 
side initiates connections to the other.  

> Notes: 
> * _only bidirectional links support fail back!_
> * _for bidirectional links with an `OUTBOUND` and an `INBOUND` side, the 
> `INBOUND` side must be created first!_

# References 
* [Configure Cluster Linking on Confluent Platform](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html)
* [Illuminating Information on Bidirectional vs Source Initiated Links](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/faqs-cp.html#does-cluster-linking-support-bidirectional-links-between-two-clusters)
* [Schema Linking](https://docs.confluent.io/platform/current/schema-registry/schema-linking-cp.html)


# Labs

## Basic Cluster Linking on Docker 

In this lab, we'll create a traditional unidirectional cluster link.  A docker 
compose configuration with 2 clusters has been provided.

Bring up the lab environment with the command below
```
docker compose -f cluster_linking.compose.yaml up -d
```

This will bring up 2 clusters, each with 1 controller, 1 schema registry and 
3 brokers.  

There is also a Confluent Control Center instance configured to monitor both 
clusters.  You can acces it at [http://localhost:9021](http://localhost:9021).

Next, lets create a topic and a schema for the key and value of the topic.

```
kafka-topics --create  --bootstrap-server localhost:19092  --topic orders --partitions 3 --replication-factor 2 --config min.insync.replicas=2 --config cleanup.policy=delete --config retention.bytes=1000000000 --config retention.ms=-1

./java-samples/data-definitions/post_schemas.sh
```

Now you can use the control center to verify that the topic and schema have 
been created on the first cluster.

Build and run the order producer in a separate terminal.  By default it will
run for an hour and exit.

```
cd java-samples
mvn clean package
java -jar batch-producer/target/batch-producer-1.0-SNAPSHOT.jar
```

Start a simple consumer in a separate window.

```
cd java-samples
java -jar simple-consumer/target/simple-consumer-1.0-SNAPSHOT.jar
```

You should now see a topic with a schema and messages, and a consumer group 
which is steadily consuming messages and committing offsets.  If you wish, 
you can run multiple instances of the simple consumer to distribute the 
consumption.

Now, lets configure schema linking from the "A" cluster to the "B" cluster.

First, note the following configurations in `cluster_linking.compose.yaml`
in the configurations for the schema registry containers. 

```
SCHEMA_REGISTRY_RESOURCE_EXTENSION_CLASS: io.confluent.schema.exporter.SchemaExporterResourceExtension
SCHEMA_REGISTRY_KAFKASTORE_UPDATE_HANDLERS: io.confluent.schema.exporter.storage.SchemaExporterUpdateHandler
SCHEMA_REGISTRY_PASSWORD_ENCODER_SECRET: changeme
```

These are required to make the schema registry capable of exporting schemas.


> What is `SCHEMA_REGISTRY_PASSWORD_ENCODER_SECRET` ?
> According to the [documentation](https://docs.confluent.io/platform/current/schema-registry/installation/config.html#password-encoder-secret) 
> this is a passphrase used to encrypt dynamically configured secrets.  In 
> a real deployment, this should be provided via an alternate means, like a 
> kubernetes secret,  not placed directly in a configuration file.


Now, we need to actually configure an [exporter](https://docs.confluent.io/platform/current/schema-registry/schema-linking-cp.html#what-is-an-exporter).  Run the following command.

```
schema-exporter --create --name export-all-to-b --subjects ":*:" --config-file schema_exporter_a.properties --context-type DEFAULT --schema.registry.url http://localhost:8081
```

Note that the configuration file in this command, 
`schema_exporter_a.properties`, contains the information needed by the 
exporter to connect to the remote (B) cluster.

You can review information about schema exporters using the `schema-exporter` 
command.  See below for some examples.
```
me@myhost % schema-exporter --list --schema.registry.url  http://localhost:8081
[export-all-to-b]
me@myhost % schema-exporter --describe --name export-all-to-b  --schema.registry.url  http://localhost:8081
{"name":"export-all-to-b","subjects":[":*:"],"contextType":"AUTO","context":".Nk018hRAQFytWskYqtQduw-schema-registry","config":{"schema.registry.url":"http://schema-registry-B1:8181"}}
me@myhost % schema-exporter --get-status --name export-all-to-b  --schema.registry.url  http://localhost:8081
{"name":"export-all-to-b","state":"RUNNING","offset":3,"ts":1776783281278,"deksOffset":-1,"deksTs":0,"retriable":false}
```

Lastly, use `curl` to check that the schemas have been propagated
```
 curl --silent -X GET http://localhost:8081/subjects # get local subjects 
 curl --silent -X GET http://localhost:8181/subjects # get remote subjects 
```

Now we can set up a cluster link.  This will be a basic cluster link so 
we will configure it on the destination.  The destination, cluster B, will 
connect to the source, cluster A, and pull new messages.  We'll also configure 
it to copy over the ACLs and consumer group offsets and to create mirror topic 
automatically.  

Run the following command:
```
kafka-cluster-links  --bootstrap-server localhost:19192 --create --config-file  cluster_link_a_to_b.properties --acl-filters-json-file acl.filters.json  --consumer-group-filters-json-file consumer.group.filters.json   --topic-filters-json-file mirror.topic.filter.json  --link a_to_b
```

# note - make mirror topic creation explicit

[Mirror configs](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html)
[Hybrid Cluster Linking Tutorial](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/hybrid-cp.html)
[Schema Linking](https://docs.confluent.io/platform/7.8/schema-registry/schema-linking-cp.html)
[Cluster Linking on CP Tutorial](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/topic-data-sharing.html)
[Cluster Linking on CP](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/index.html)





