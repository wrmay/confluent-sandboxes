import os
import random
import sys
import time
import uuid

from cards import fake_cards


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
    result["merchant_id"] = f'{random.randrange(0, 9999):04d}'    
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

    result["amount"] = amt

    return result

if __name__ == '__main__':
    for env_var in ["KAFKA_BOOTSTRAP_SERVERS", "KAFKA_SCHEMA_REGISTRY_URL","KAFKA_TRANSACTION_TOPIC", "KAFKA_CARD_TOPIC", "CARD_COUNT", "TRANSACTIONS_PER_SEC"]:
        if env_var not in os.environ:
            sys.exit(f"Missing required environment variable: {env_var}")

    # could stand to validate these values
    card_count = int(os.getenv('CARD_COUNT'))
    txns_per_sec = int(os.getenv('TXNS_PER_SEC'))
    bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS')
    schema_registry_url = os.getenv('KAFKA_SCHEMA_REGISTRY_URL')
    card_topic = os.getenv('KAFKA_CARD_TOPIC')
    transaction_topic = os.getenv('KAFKA_TRANSACTION_TOPIC')

    cards = fake_cards(card_count)
    
    kafka_config = {
        "bootstrap.servers": bootstrap_servers,
        "schema.registry.url": schema_registry_url,
        "value.serializer": "io.confluent.kafka.serializers.KafkaAvroSerializer",
        "key.serializer" : "io.confluent.kafka.serializers.KafkaStringSerializer"
    }
    producer = Producer(kafka_config)
    for card in cards:
        # should check return val
        producer.produce(card_topic, card, key=card['card_number'])
        
    producer.flush()
    print(f'produced {card_count} cards to {card_topic}')

    seconds_per_txn = 1/ txns_per_sec
    start = time.time()

    # here

    producer.close()