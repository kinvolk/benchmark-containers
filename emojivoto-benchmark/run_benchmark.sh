#!/bin/bash

script_location="$(dirname "${BASH_SOURCE[0]}")"

if [ "$#" -ne 2 ]; then
    echo "usage: $0 EMOJIVOTO_INSTANCES MACHINE_TYPE"
    exit 1
fi

emojivoto_limit="$(( $1 - 1 ))"
machine="$2"

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
    for rps in 1000 3000 5000; do
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
