#!/bin/bash

set -euo pipefail

function log() {
  local message="${1:-""}"
  echo -e "\\033[1;37m${message}\\033[0m"
}

function err() {
  local message="${1:-""}"
  echo -e >&2 "\\033[1;31m${message}\\033[0m"
}

function verify_binaries_download() {
  binaries='terraform helm kubectl lokoctl'
  for b in $binaries
  do
    while ! ls "/binaries/${b}" >/dev/null 2>&1
    do
      log "Waiting for ${b} to be available..."
      sleep 1
    done
    log "Copying /binaries/${b} to /usr/local/bin/"
    /bin/cp "/binaries/${b}" /usr/local/bin/
  done
}

verify_binaries_download

log "Cluster name: ${CLUSTER_NAME}"

cd /clusters
mkdir -p "${CLUSTER_NAME}" && cd "${CLUSTER_NAME}"
cp /scripts/"${CLOUD}".lokocfg .
cp /scripts/"${CLOUD}".vars.envsubst .

public_key=$(cat ~/.ssh/id_rsa.pub)
export SSH_PUB_KEY=${public_key}
envsubst < "${CLOUD}".vars.envsubst > lokocfg.vars
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa
ssh-add -L

lokoctl cluster apply -v --confirm --skip-components

n=0
until [ "$n" -ge 10 ]
do
  lokoctl component apply && break
  n=$((n+1))
  sleep 5
  log "retry #${n}"
  log "retrying 'lokoctl component apply' again..."
done

# Make an entry in the OC about this BC
# This uses service account credentials to talk to apiserver
kubectl -n monitoring patch prometheus prometheus-operator-kube-p-prometheus --type merge --patch '{"spec":{"additionalScrapeConfigs":{"name":"scrape-config","key":"scrape.yaml"}}}'

if ! kubectl -n monitoring get secret scrape-config; then
  err "could not find secret 'scrape-config' in 'monitoring' namespace on orchestrating cluster"
  cat > /tmp/scrape.yaml <<EOF
- job_name: 'federate'
  scrape_interval: 15s

  honor_labels: true
  metrics_path: '/federate'

  params:
    'match[]':
    - '{job=~"node-exporter|kube-state-metrics|pushgateway|kubelet"}'
    - 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate'
    - '{__name__=~"job:.*"}'

  static_configs:
  - targets:
EOF
  log "creating secret 'scrape-config' in 'monitoring' namespace on orchestrating cluster"
  kubectl -n monitoring create secret generic scrape-config --from-file=/tmp/scrape.yaml
fi

kubectl -n monitoring get secret scrape-config -ojsonpath='{.data.scrape\.yaml}' | base64 -d > /tmp/scrape.yaml
echo "    - 'prometheus.$CLUSTER_NAME.dev.lokomotive-k8s.net'" | tee -a /tmp/scrape.yaml
kubectl -n monitoring create secret generic scrape-config --from-file=/tmp/scrape.yaml --dry-run=client -o yaml | kubectl -n monitoring apply -f -
log "updated scrape config"
cat /tmp/scrape.yaml

# Wait for sometime because prometheus can take some time to start scraping
log "waiting for promtheus to apply above setting..."
sleep 180

mkdir -p ~/.kube
cp ./assets/cluster-assets/auth/kubeconfig ~/.kube/config
cp -r /binaries/service-mesh-benchmark .
cp -r /binaries/benchmark-containers .

# Deploy pushgateway in monitoring namespace
function install_pushgateway() {
  cd /clusters/"${CLUSTER_NAME}"/service-mesh-benchmark/configs/pushgateway
  helm install --timeout=10m pushgateway --namespace monitoring . || true
}

function wait_for_job() {
  local ns="${1}"
  local job="${2}"

  # Wait for the job to finish
  while true
  do
    complete=$(kubectl -n "${ns}" get job "${job}" -o jsonpath='{.status.completionTime}')
    #
    if [ -z "${complete}" ]; then
      log "waiting for job ${job} to finish in ${ns} namespace"
    else
      break
    fi
    sleep 10
  done
}

function run_pytorch_benchmark() {
  name="pytorch-benchmark-${1}"
  values_file="$(mktemp).yaml"

  if kubectl get ns "${name}" >/dev/null 2>&1; then
    log "Pytorch already installed!"
    return
  fi

    echo "
cloud: ${CLOUD}
instance: ${BENCHMARK_INSTANCE_TYPE}

nodeSelector:
  role: benchmark

tolerations:
- key: role
  operator: Equal
  value: benchmark
  effect: NoSchedule
" | tee "${values_file}"

  cd /clusters/"${CLUSTER_NAME}"/benchmark-containers/pytorch/helm
  while true; do
    helm install --timeout=10m --create-namespace "${name}" \
    --namespace "${name}" --values="${values_file}" . && break
    log "Trying to install pytorch again..."
    sleep 1
  done

  wait_for_job "${name}" pytorch-benchmark
}

function run_memtier_benchmark() {
  name="memtier-benchmark-${1}"
  values_file="$(mktemp).yaml"

  if kubectl get ns "${name}" >/dev/null 2>&1; then
    log "Memtier already installed!"
    return
  fi

  echo "
cloud: ${CLOUD}
instance: ${BENCHMARK_INSTANCE_TYPE}

nodeSelector:
  role: benchmark

tolerations:
- key: role
  operator: Equal
  value: benchmark
  effect: NoSchedule
" | tee "${values_file}"

  cd /clusters/"${CLUSTER_NAME}"/benchmark-containers/memtier/helm
  while true; do
    helm install --timeout=10m --create-namespace "${name}" \
    --namespace "${name}" --values="${values_file}" . && break
    log "Trying to install Memtier benchmark again..."
    sleep 1
  done

  wait_for_job "${name}" run-memtier-benchmark
}

function run_mysql_benchmark() {
  name="mysql-benchmark-${1}"
  values_file="$(mktemp).yaml"

  if kubectl get ns "${name}" >/dev/null 2>&1; then
    log "MySQL benchmark already installed!"
    return
  fi

  echo "
cloud: ${CLOUD}
instance: ${BENCHMARK_INSTANCE_TYPE}

nodeSelector:
  role: benchmark

tolerations:
- key: role
  operator: Equal
  value: benchmark
  effect: NoSchedule
" | tee "${values_file}"

  cd /clusters/"${CLUSTER_NAME}"/benchmark-containers/mysql/helm
  while true; do
    helm install --timeout=10m --create-namespace "${name}" \
    --namespace "${name}" --values="${values_file}" . && break
    log "Trying to install MySQL benchmark again..."
    sleep 1
  done

  wait_for_job "${name}" run-mysql-benchmark
}

function run_nginx_benchmark() {
  name="nginx-benchmark-${1}"
  values_file="$(mktemp).yaml"

  if kubectl get ns "${name}" >/dev/null 2>&1; then
    log "Nginx benchmark already installed!"
    return
  fi

  echo "
cloud: ${CLOUD}
instance: ${BENCHMARK_INSTANCE_TYPE}

nodeSelector:
  role: benchmark

tolerations:
- key: role
  operator: Equal
  value: benchmark
  effect: NoSchedule
" | tee "${values_file}"

  cd /clusters/"${CLUSTER_NAME}"/benchmark-containers/nginx/helm
  while true; do
    helm install --timeout=10m --create-namespace "${name}" \
    --namespace "${name}" --values="${values_file}" . && break
    log "Trying to install Nginx benchmark again..."
    sleep 1
  done

  wait_for_job "${name}" run-nginx-benchmark
}

install_pushgateway

# Run each benchmark thrice.
for ((i=0;i<3;i++))
do
  run_pytorch_benchmark "${i}"
  run_memtier_benchmark "${i}"
  run_mysql_benchmark "${i}"
  run_nginx_benchmark "${i}"
done
