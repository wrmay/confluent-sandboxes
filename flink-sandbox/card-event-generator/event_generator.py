from decimal import Decimal
import json
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
# Reads all configuration from "config.json" in the current directory .
# A sample is shown below.
#
#{
#    "kafka": {
#        "bootstrap.servers" : "abc.def:9092",
#        "security.protocol": "SASL_SSL",
#         "sasl.mechanisms" : "PLAIN",
#         "sasl.username": "zzzzzzz",
#         "sasl.password" : "qqqqqqqqqqqqqqqqqq",
#         "session.timeout.ms": 45000,
#         "client.id": "card_event_generator"
#     },
#     "schema_registry": {
#         "url": "https://schemas.acme",
#         "basic.auth.credentials.source": "USER_INFO",
#         "basic.auth.user.info": "uuuu:zzzzzzzzzzzzzzzzzz"
#     },
#     "event_generator": {
#         "card_count": 100,
#         "txns_per_sec": 100,
#         "transaction_topic": "transactions"
#     }
# }


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
    if os.path.isfile("config.json"):
        with open('config.json', "r") as f:
            config = json.load(f)
    
    else:
        sys.exit(f"Required configuration file, 'config.json' was not found. Exiting.")

    if 'event_generator' in config:
        event_generator_config = config['event_generator']
        card_count = event_generator_config['card_count']
        txns_per_sec = event_generator_config['txns_per_sec']
        transaction_topic = event_generator_config['transaction_topic']
    else:
        sys.exit("Required config entry 'event_generator' is not present.")

    if 'kafka' in config:
        kafka_config = config['kafka']
    else:
        sys.exit("Required config entry 'kafka' is not present.")
        
    if 'schema_registry' in config:
        schema_registry_config = config['schema_registry']
    else:
        sys.exit("Required config 'schema_registry' is not present.")

    if os.path.isfile("transaction.avsc"):
        with open("transaction.avsc") as f:
            schema_str = f.read()
    else:
        sys.exit("Required file: 'transaction.avsc' not found.")

    # create the fake cards 
    cards = fake_cards(card_count)

    # create the schema registry client and the Avro serializer
    with SchemaRegistryClient(schema_registry_config) as schema_registry_client:
        value_serializer = AvroSerializer(
            schema_registry_client=schema_registry_client,
            schema_str = schema_str
        )

        kafka_config["value.serializer"] = value_serializer
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


