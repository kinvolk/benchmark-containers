#!/bin/bash

script_location="$(dirname "${BASH_SOURCE[0]}")"

if [ "$#" -ne 5 ]; then
    echo "usage: $0 EMOJIVOTO_INSTANCES MACHINE_TYPE INITIAL_RPS RPS_STEP FINAL_RPS"
    exit 1
fi

emojivoto_limit="$(( $1 - 1 ))"
machine="$2"
initial_rps="$3"
rps_step="$4"
final_rps="$5"

if [ $emojivoto_limit -ge 35 ]; then
    kubectl calico apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: benchmark-pool
spec:
  cidr: 10.0.0.0/16
  blockSize: 20
  ipipMode: Always
  natOutgoing: true
EOF
    UNLEASHED="$(kubectl -n kube-system get daemonset kubelet -o yaml | grep 'max-pods=500')"
    if [ -z "$UNLEASHED" ]; then
        kubectl -n kube-system patch daemonset kubelet --patch "$(cat kubelet-patch.yaml)"
    fi

    UNLEASHED="yes"
fi

function grace() {
    grace=10
    [ -n "$2" ] && grace="$2"

    while true; do
        eval $1
        if [ $? -eq 0 ]; then
            sleep 1
            grace=10
            continue
        fi

        if [ $grace -gt 0 ]; then
            sleep 1
            echo "grace period: $grace"
            grace=$(($grace-1))
            continue
        fi

        break
    done
}
# --

function install_emojivoto() {
    echo "Installing emojivoto."

    for num in $(seq 0 1 $emojivoto_limit); do
        {
            kubectl create namespace emojivoto-$num
            if [ -n "$UNLEASHED" ]; then
                kubectl annotate namespace emojivoto-$num "cni.projectcalico.org/ipv4pools"='["benchmark-pool"]'
            fi

            helm install emojivoto-$num --namespace emojivoto-$num \
                             ${script_location}/helm/emojivoto/
         } &
    done

    wait

    grace "kubectl get pods --all-namespaces | grep emojivoto | grep -v Running" 10
}
# --

function restart_emojivoto_pods() {

    for num in $(seq 0 1 $emojivoto_limit); do
        local ns="emojivoto-$num"
        echo "Restarting pods in $ns"
        {  local pods="$(kubectl get -n "$ns" pods | grep -vE '^NAME' | awk '{print $1}')"
            kubectl delete -n "$ns" pods $pods --wait; } &
    done

    wait

    grace "kubectl get pods --all-namespaces | grep emojivoto | grep -v Running" 10
}
# --

function delete_emojivoto() {
    echo "Deleting emojivoto."

    for i in $(seq 0 1 $emojivoto_limit); do
        { helm uninstall emojivoto-$i --namespace emojivoto-$i;
          kubectl delete namespace emojivoto-$i --wait; } &
    done

    wait

    grace "kubectl get namespaces | grep emojivoto"
}
# --

function run() {
    echo "   Running '$@'"
    $@
}
# --

function install_benchmark() {
    local machine="$1"
    local rps="$2"

    local duration=600
    local init_delay=10

    local app_count=$(kubectl get namespaces | grep emojivoto | wc -l)

    echo "Running $machine benchmark"
    kubectl create ns benchmark
    if [ -n "$UNLEASHED" ]; then
        kubectl annotate namespace benchmark "cni.projectcalico.org/ipv4pools"='["benchmark-pool"]'
    fi
    helm install benchmark --namespace benchmark \
        --set wrk2.machine="$machine" \
        --set wrk2.app.count="$app_count" \
        --set wrk2.RPS="$rps" \
        --set wrk2.duration=$duration \
        --set wrk2.connections=128 \
        --set wrk2.initDelay=$init_delay \
        ${script_location}/helm/benchmark/
}
# --

function run_bench() {
    local machine="$1"
    local rps="$2"

    install_benchmark "$machine" "$rps"
    grace "kubectl get pods -n benchmark | grep wrk2-prometheus | grep -v Running" 10

    echo "Benchmark started."

    while kubectl get jobs -n benchmark \
            | grep wrk2-prometheus \
            | grep -qv 1/1; do
        kubectl logs \
                --tail 1 -n benchmark  jobs/wrk2-prometheus -c wrk2-prometheus
        sleep 10
    done

    echo "Benchmark concluded. Updating summary metrics."
    helm install --create-namespace --namespace metrics-merger \
        metrics-merger ${script_location}/helm/metrics-merger/
    sleep 5
    while kubectl get jobs -n metrics-merger \
            | grep wrk2-metrics-merger \
            | grep  -v "1/1"; do
        sleep 1
    done

    kubectl logs -n metrics-merger jobs/wrk2-metrics-merger

    echo "Cleaning up."
    helm uninstall benchmark --namespace benchmark
    kubectl delete ns benchmark --wait
    helm uninstall --namespace metrics-merger metrics-merger
    kubectl delete ns metrics-merger --wait
}
# --

function run_benchmarks() {
    for rps in $(seq $initial_rps $rps_step $final_rps); do
        for repeat in 1 2; do
            echo "########## Run #$repeat w/ $rps RPS"

            echo " +++ bare metal benchmark"
            install_emojivoto
            run_bench $machine $rps
            delete_emojivoto
        done
    done
}
# --

if [ "$(basename $0)" = "run_benchmark.sh" ] ; then
    run_benchmarks $@
fi
