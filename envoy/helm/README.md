# Envoy

### How to install

Make sure you have a lokomotive cluster up and running with [pushgateway](https://github.com/kinvolk/service-mesh-benchmark/tree/master/configs/pushgateway) installed.

```bash
helm install \
  --create-namespace \
  --namespace envoy \
  envoy .
```

### How to uninstall
```bash
helm uninstall envoy -n envoy

kubectl delete ns envoy
```
