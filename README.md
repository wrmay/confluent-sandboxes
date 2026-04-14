# Lab Notes

The basic environment runs under Docker.

Start it with `docker compose up -d`

The Confluent UI is at http://localhost:9021.

Stop it with `docker compose down`

Data will persist across restarts because it lives in Docker volumes. 
To bring the environment down and remove the volumes, use `docker compose down -v`
