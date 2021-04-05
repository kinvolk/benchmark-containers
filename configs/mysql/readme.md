# MYSQL

### How to install

Make sure you have lokomotive cluster up and running.

```bash
# Create namespace
kubectl create ns mysql

# To install, run this from the root of the directory.
helm install mysql configs/mysql -n mysql

# To uninstall
helm uninstall mysql -n mysql
```
