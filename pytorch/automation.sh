#!/bin/bash
#
# pytorch automation.sh - script to deploy and run the pytorch benchmark on a number of clusters
#

pytorch_usage() {
    echo "Usage:"
    echo "  $0 [-p <pushgateway-url>] [-c <num cpus>] <kubeconfig>,<cloud>,<shape> [<kubeconfig>,<cloud>,<shape> [...]] "
    echo "  <kubeconfig>     - kubeconfig file for this cluster"
    echo "  <cloud>          - cloud name to use for pushgateway reports"
    echo "  <shape>          - instance / shape name to use for pushgateway reports"
    echo "Options:"
    echo " -p <push-gateway> - URL of prometheus push gateway."
    echo "                     Helm chart default: http://monitoring.pushgateway:9091/"
    echo " -c <num cpus>     - Force a number of CPUs to use (auto-caps to CPUs available)."
    echo "                     By default the benchmark will use all CPUs available."
    echo
}
# ---

pytorch_start_single() {
    local kubeconfig="$1"
    local cloud="$2"
    local shape="$3"
    local cpus="$4"
    local pushgw="$5"

    scriptdir="$(dirname "$0")"

    local cmdl="--set cloud='$cloud' --set instance='$shape' --create-namespace --namespace pytorch-benchmark pytorch-benchmark $scriptdir/helm/"
    if [ -n "$cpus" ] ; then
        cmdl="--set numCpus=$cpus $cmdl"
    fi
    if [ -n "$pushgw" ] ; then
        cmdl="--set customPushgwURL=$pushgw $cmdl"
    fi
    cmdl="helm install $cmdl"

    echo "### Starting pytorch benchmark on cloud '$cloud' shape '$shape' using '$kubeconfig'"
    echo "### $ $cmdl"
    export KUBECONFIG="$kubeconfig"
    $cmdl
    export KUBECONFIG=""
}
# ---

pytorch_get_status() {
    local kubeconfig="$1"

    export KUBECONFIG="$kubeconfig"
    # prints the first part of completion status, e.g. "0" when status is "0/1"
    kubectl get jobs -n pytorch-benchmark | awk '/pytorch-benchmark/ {print substr($2,1,1)}'
    export KUBECONFIG=""
}
# ---

pytorch_main() {
    local pgw=""
    local cpus=""

    local clusters

    if [ $# -le 0 ] ; then
        pytorch_usage
        exit
    fi

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            -h) pytorch_usage; exit; ;;
            -p) shift; pgw="$1"; shift;;
            -c) shift; cpus="$1"; shift;;
            *) clusters="$clusters $1"; shift;;
        esac
    done

    if [ -z "$clusters" ]; then
        pytorch_usage
        exit 1
    fi

    local c
    for c in $clusters; do
        # a,b,c => a b c
        c=$(echo "$c" | sed 's/,/ /g')
        pytorch_start_single $c "$cpus" "$pgw"
        echo ""
    done

    echo "### Waiting for completion"

    local compl=false
    while ! $compl; do
        compl=true
        local status="### "
        for c in $clusters; do
            c=$(echo "$c" | sed 's/,/ /g')
            local -a a=($c)
            local s=$(pytorch_get_status ${a[0]})

            status="$status ${a[1]}/${a[2]}"
            if [ "$s" = "0" ] ; then
                status="$status:not done, "
                compl=false
            else
                status="$status:done, "
            fi
        done
        echo -en "\r$status                              "
    done
    echo ""
    echo "### All done."
}

if [ "$(basename "$0")" = "automation.sh" ] ; then
    pytorch_main $@
fi
