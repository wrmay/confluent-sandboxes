
## Create topic command
```bash
 docker compose run tools kafka-topics --create  --bootstrap-server kafka-1:9092  --topic orders --partitions 3 --replication-factor 2 --config min.insync.replicas=2 --config cleanup.policy=delete --config retention.bytes=1000000000 --config retention.ms=-1
 ````
   
## Clear consumer group command
```bash
 docker compose run tools kafka-consumer-groups --bootstrap-server kafka-1:9092  --group OrderConsumer --all-topics --delete
```
