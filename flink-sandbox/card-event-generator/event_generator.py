from decimal import Decimal
import os
import random
import sys
import time
from typing import Callable
import uuid

from confluent_kafka import Producer

from cards import fake_cards
from confluent_kafka.serialization import StringSerializer
from confluent_kafka.serializing_producer import SerializingProducer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer


#
# Requires the following environment variables
# 
# CARD_COUNT
# TXNS_PER_SEC
# KAFKA_BOOTSTRAP_SERVERS
# KAFKA_SCHEMA_REGISTRY_URL
# KAFKA_TRANSACTION_TOPIC
# KAFKA_CARD_TOPIC
#


def fake_txn(ccnum: str):
    result = dict()
    result["card_number"] = ccnum
    result["merchant_id"] = random.randrange(0, 9999)
    result["transaction_id"] = str(uuid.uuid4())

    rnum = random.random()
    if rnum < 0.01:
        amt = 1000000
    elif rnum < .1:
        amt = random.randrange(1000, 5000)
    elif rnum < .5:
        amt = random.randrange(100, 1000)
    else:
        amt = random.randrange(1, 100)

    result["amount"] = Decimal(amt)

    return result


def delivery_report(err, msg):
    if err is not None:
        print(f"Delivery failed: {err}")
    # else:
    #     print(f"Delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}")


if __name__ == '__main__':
    for env_var in ["KAFKA_BOOTSTRAP_SERVERS", "KAFKA_SCHEMA_REGISTRY_URL","KAFKA_TRANSACTION_TOPIC", "KAFKA_CARD_TOPIC", "CARD_COUNT", "TXNS_PER_SEC"]:
        if env_var not in os.environ:
            sys.exit(f"Missing required environment variable: {env_var}")

    # could stand to validate these values
    card_count = int(os.getenv('CARD_COUNT'))
    txns_per_sec = int(os.getenv('TXNS_PER_SEC'))
    bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS')
    schema_registry_url = os.getenv('KAFKA_SCHEMA_REGISTRY_URL')
    card_topic = os.getenv('KAFKA_CARD_TOPIC')
    transaction_topic = os.getenv('KAFKA_TRANSACTION_TOPIC')

    # create the fake cards 
    cards = fake_cards(card_count)

    # create the schema registry client and the Avro serializer
    with SchemaRegistryClient({"url": schema_registry_url}) as schema_registry_client:
        value_serializer = AvroSerializer(
            schema_registry_client=schema_registry_client,
            conf={
                "auto.register.schemas": False,
                "use.latest.version": True,
            }
        )

        kafka_config = {
            "bootstrap.servers": bootstrap_servers,
            "value.serializer": value_serializer,
            "key.serializer" : StringSerializer("utf_8")
        }
        with SerializingProducer(kafka_config) as producer:
            seconds_per_txn = 1/ txns_per_sec
            start = time.time()
            next_txn_due = start + seconds_per_txn
            produced = 0
            while True:
                sleep_time = next_txn_due - time.time()
                if sleep_time < -5:
                    print("Can't keep up, exiting")
                    break
                elif sleep_time > .01:
                    time.sleep(sleep_time)

                cnum = random.choice(cards)["card_number"]
                producer.produce(
                    topic=transaction_topic, 
                    value=fake_txn(cnum),
                    key=cnum,
                    on_delivery=delivery_report)
                
                produced += 1
                if produced % 1000 == 0:
                    print(f'produced {produced} transactions so far ...')
                    producer.poll(2)

                next_txn_due += seconds_per_txn


