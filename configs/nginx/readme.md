# Nginx

### How to install

Make sure you have a lokomotive cluster up and running with [pushgateway](https://github.com/kinvolk/service-mesh-benchmark/tree/master/configs/pushgateway) installed.

```bash
helm install \
  --create-namespace \
  --namespace nginx \
  nginx .
```

### How to uninstall

```bash
helm uninstall nginx -n nginx

kubectl delete ns nginx
```
