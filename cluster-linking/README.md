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

### Bidirectional
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
* [Bidirectional Links with One Way Connectivity](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/configs.html?session_ref=https%3A%2F%2Fdocs.confluent.io%2Fplatform%2Fcurrent%2Fmulti-dc-deployments%2Fcluster-linking%2Fconfigs.html&url_ref=https%3A%2F%2Fdocs.confluent.io%2Fsearch.html#advanced-options-for-bidirectional-cluster-linking)
* [Schema Linking](https://docs.confluent.io/platform/current/schema-registry/schema-linking-cp.html)


# Labs

## Creating a Bidirectional Cluster Link with 1-way Connectivity

In this lab, cluster B will accept connections but will not initiate 
them.  Cluster A will initiate all connections.


Bring up the lab environment with the command below
```
docker compose -f cluster_linking.compose.yaml up -d
```

This will bring up 2 clusters, each with 1 controller, 1 schema registry and 
3 brokers.  

There is also a Confluent Control Center instance configured to monitor both 
clusters.  You can acces it at [http://localhost:9021](http://localhost:9021).


Create the link(s) using the commands below.  
* The INBOUND side of the link (B) must be created first.  
* Review `b-link.config` and `a-link.config`.  
  * Notice that that `a-link.config` has a `bootstrap.servers` property for 
  connecting to cluster B, but `b-link.config` does not have a `bootstrap.servers` 
  property.
  * Note that both files set the `local.listener.name` property.  This is 
    because the link itself must talk to the local cluster as well as the 
    remote cluster.  Without this, the link will use whatever was passed 
    as the `--bootstrap.server` argument to the `kafka-cluster-links` command 
    that created the link.

```
kafka-cluster-links --create --link my-bidi-link --config-file b-link.config --cluster-id Nk018hRAQFytWskYqtQduw   --bootstrap-server localhost:19192

kafka-cluster-links --create --link my-bidi-link --config-file a-link.config --cluster-id CGO4QV6YQtmwRivSayL_Hw --bootstrap-server localhost:19092
```

Now, to test, we can create a couple of topics, one that will be writable 
only on cluster A, and the other on cluster B.

```
 kafka-topics --bootstrap-server localhost:19092 --create --topic a-writeable --partitions 3 --replication-factor 2 --config min.insync.replicas=2 --config cleanup.policy=delete --config retention.bytes=1000000000 --config retention.ms=1

 kafka-topics --bootstrap-server localhost:19192 --create --topic b-writeable --partitions 3 --replication-factor 2 --config min.insync.replicas=2 --config cleanup.policy=delete --config retention.bytes=1000000000 --config retention.ms=1
```

Now, you can create the mirrors of both topics on both clusters.

Create Mirrors
```
# create a mirror of a-writeable on cluster b
kafka-mirrors --create --mirror-topic a-writeable --link my-bidi-link --bootstrap-server localhost:19192

# create a mirror of b-writeable on cluster a
kafka-mirrors --create --mirror-topic b-writeable --link my-bidi-link --bootstrap-server localhost:19092
```

You can now test.  You can use the Confluent Console to create messages or 
`kafka-console-producer`.  Verify that you are not able to write to the mirror 
topics

Amaze! Amaze! Amaze!

