#!/bin/bash

[ $# -lt 2 ] && {
    echo
    echo "$0 - Upload a Grafana dashboard(JSON file) to Grafana" 
    echo "Usage: $0 <grafana-API-keyfile> <dashboard-file> [<hostname-and-port>]"
    echo "          Hostname/port is assumed to be localhost:3000 if not provided."
    echo "          (use"
    echo "            kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80"
    echo "           for lokomotive kubernetes)"
    exit 1
}

apikey="$(cat "$1")"
dashboard="$2"
if [ $# -ge 3 ]; then
    host="$3"
else
    host="localhost:3000"
fi

echo "Uploading dashboard file $dashboard"

out=$(mktemp)

cat  "$dashboard" \
         | jq '. * {overwrite: true, dashboard: {id: null}}' \
         | curl -X POST \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $apikey" \
                http://$host/api/dashboards/import -d @- | tee $out

echo -e "\nDashboard available at $host/$(cat "$out" | jq -r '.importedUrl')"

rm -f "$out"
