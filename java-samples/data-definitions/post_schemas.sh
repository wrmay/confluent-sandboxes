#!/bin/bash
#
# This seems rediculously difficult.  How can we make this easier ?
#
SCHEMA_DIR=`dirname $0`/src/main/avro
SCHEMA_AS_STRING=`cat $SCHEMA_DIR/orders.avsc | sed 's/\"/\\\"/g' | tr -d '\n'`
SCHEMA_BODY="{ \"schema\": \"$SCHEMA_AS_STRING\"}"
curl -X POST -v  http://localhost:8081/subjects/orders-value/versions  -H "Content-Type: application/vnd.schemaregistry.v1+json" -d "$SCHEMA_BODY"

SCHEMA_AS_STRING=`cat $SCHEMA_DIR/int.avsc | sed 's/\"/\\\"/g' | tr -d '\n'`
SCHEMA_BODY="{ \"schema\": \"$SCHEMA_AS_STRING\"}"
curl -X POST -v  http://localhost:8081/subjects/orders-key/versions  -H "Content-Type: application/vnd.schemaregistry.v1+json" -d "$SCHEMA_BODY"
