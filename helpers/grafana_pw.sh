# Helper to print the Grafana admin password

kubectl -n monitoring get secret prometheus-operator-grafana -o jsonpath='{.data.admin-password}' | base64 -d && echo
