# Memtier

### How to install

Make sure you have a lokomotive cluster up and running with [pushgateway](https://github.com/kinvolk/service-mesh-benchmark/tree/master/configs/pushgateway) installed.

```bash
helm install \
  --create-namespace \
  --namespace memtier \
  memtier .
```

### How to uninstall
```bash
helm uninstall memtier -n memtier

kubectl delete ns memtier
```
