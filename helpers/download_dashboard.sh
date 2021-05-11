#!/bin/bash


[ $# -lt 2 ] && {
    echo
    echo "$0 - download (backup) a Grafana dashboard, write to STDOUT"
    echo "Usage: $0 <grafana-API-key> <dashboard-id> [<hostname-and-port>] [>dashboard-backup.json]"
    echo "          Hostname/port is assumed to be localhost:3000 if not provided."
    echo "          (use"
    echo "            kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80"
    echo "           for lokomotive kubernetes)"
    exit 1
}

apikey="$(cat "$1")"
dashboard_uid="$2"
if [ $# -ge 3 ]; then
    host="$3"
else
    host="localhost:3000"
fi

echo "Downloading dashboard UID $dashboard_uid from $host" >&2


curl -sH "Authorization: Bearer $apikey" \
                http://$host/api/dashboards/uid/$dashboard_uid \
        | sed -e "s/\"$dashboard_uid\"/null/" -e 's/,"url":"[^"]\+",/,/' | jq
