# Collection of helper scripts for often-needed cluster operations

## Get the Grafana admin password of a Lokomotive cluster

```shell
$ export KUBECONFIG=my-cluster-kubeconfig
$ ./grafana_pw.sh
[...password is printed to stdout]
```

## Forward the ports of Grafana, Prometheus, and the pushgateway to the local machine

* Prometheus: port 9090
* Pushgateway: port 9091
* Grafana: port 3000

```shell
$ export KUBECONFIG=my-cluster-kubeconfig
$ source ./forward.source
...
$ jobs
[1]   Running                 kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80 &
[2]-  Running                 kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
[3]+  Running                 kubectl port-forward -n monitoring svc/pushgateway 9091:9091 &
```

## Upload and download Grafana dashboards

First, we need to create an API key with write access to Grafana.
This can be done in the Grafana UI (Gear icon -> API keys).
Copy+paste the key into a local file, e.g. `.key`.

## Upload

Upload comes in handy when setting up a new Grafana instance.
The script helps with pushing the local repository's dashboards to Grafana.

```shell
$ export KUBECONFIG=my-cluster-kubeconfig
$ ./upload_dashboard.sh <grafana-API-keyfile> <dashboard-file>
```

e.g.
```shell
$ ./upload_dashboard.sh .key ../pytorch/grafana/pytorch.dashboard
```

## Download

Download is handy e.g. if you made changes to the dashboard in Grafana (don't forget to save!).
The script can then be used to update a local dashboard file and file a PR.
You'll need a dashboard's UID for downloading.
The UID is part of the Dashboard URL, e.g. for `http://localhost:3000/d/ecXQ9TjGk/pytorch` the UID is `ecXQ9TjGk`.
The dashboard JSON will be printed to STDOUT so you might want to redirect the output into a file.

```shell
$ export KUBECONFIG=my-cluster-kubeconfig
$ ./download_dashboard.sh <grafana-API-key> <dashboard-id>
```

e.g.
```shell
$ ./download_dashboard.sh .key ecXQ9TjGk > ../pytorch/grafana/pytorch.dashboard
```
