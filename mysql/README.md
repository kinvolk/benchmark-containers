# MySQL Benchmark

This container provides a script to run benchmarks on MySQL server deployed within the same container.

## Running on Kubernetes

Prerequisites:
* Access to a Kubernetes cluster via kubectl.
* Helm.
* Grafana, Prometheus, and the Prometheus Pushgateway set up in the cluster.
* Add the [Grafana dashboard](grafana/dashboard.json) for this benchmark to the cluster's Grafana.

## Running benchmarks on Kubernetes

Follow the instructions as mentioned in this [README](helm/README.md).
## Build Container Image

Run the following command to build the container image to run MySQL benchmarks:

```bash
make build-image
```

## Build and Push Container Image

Execute this command to build and push the MySQL benchmark container image:

```bash
make push-image
```
