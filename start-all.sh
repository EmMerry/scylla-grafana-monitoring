#!/usr/bin/env bash

usage="$(basename "$0") [-h] [-d Prometheus data-dir] -- starts Grafana and Prometheus Docker instances"

while getopts ':hd:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    d) DATA_DIR=$OPTARG
       ;;
    :) printf "missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done

if [ -z $DATA_DIR ]
then
    sudo docker run -d -v $PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:Z -p 9090:9090 --name aprom prom/prometheus:v1.0.0
else
    echo "Loading prometheus data from $DATA_DIR"
    sudo docker run -d -v $DATA_DIR:/prometheus -v $PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:Z -p 9090:9090 --name aprom prom/prometheus:v1.0.0
fi

sudo docker run -d -i -p 3000:3000 \
     -e "GF_AUTH_BASIC_ENABLED=false" \
     -e "GF_AUTH_ANONYMOUS_ENABLED=true" \
     -e "GF_AUTH_ANONYMOUS_ORG_ROLE=Admin" \
     -e "GF_INSTALL_PLUGINS=grafana-piechart-panel" \
     --name agraf grafana/grafana:3.1.0

# Wait till Grafana API
until $(curl --output /dev/null -f --silent http://localhost:3000/api/org); do
    printf '.'
    sleep 5
done

DB_IP="$(sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' aprom)"

curl -XPOST -i http://localhost:3000/api/datasources \
     --data-binary '{"name":"prometheus", "type":"prometheus", "url":"'"http://$DB_IP:9090"'", "access":"proxy", "basicAuth":false}' \
     -H "Content-Type: application/json"
curl -XPOST -i http://localhost:3000/api/dashboards/db --data-binary @./grafana/scylla-dash.json -H "Content-Type: application/json"
curl -XPOST -i http://localhost:3000/api/dashboards/db --data-binary @./grafana/scylla-dash-per-server.json -H "Content-Type: application/json"
curl -XPOST -i http://localhost:3000/api/dashboards/db --data-binary @./grafana/scylla-dash-io-per-server.json -H "Content-Type: application/json"
