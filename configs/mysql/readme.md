# MYSQL

### How to install

Make sure you have a lokomotive cluster up and running with [pushgateway](https://github.com/kinvolk/service-mesh-benchmark/tree/master/configs/pushgateway) installed.

```bash
helm install \
  --create-namespace \
  --namespace mysql \
  mysql .
```

### How to uninstall

```bash
helm uninstall mysql -n mysql

kubectl delete ns mysql
```
