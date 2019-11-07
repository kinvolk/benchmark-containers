#!/bin/bash
set -euo pipefail
script_dir=$(cd $(dirname "${BASH_SOURCE[0]}"); pwd)

COMBINATIONS="benchmark+gather benchmark+gather+plot gather+plot gather+plot+cleanup benchmark+gather+cleanup benchmark+gather+plot+cleanup"

if [ "$#" != 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: $0 benchmark|gather|plot|cleanup|COMBINATION"
  echo "  benchmark: Runs benchmarks as Kubernetes Jobs on the cluster (starts sequentially with waiting for completion)"
  echo "  gather:    Write the Kubernetes Job output to local CSV files"
  echo "  plot:      Plot all existing CSVs in the current folder as SVGs"
  echo "  cleanup:   Deletes the Kubernetes Jobs (optional cleanup)"
  echo "  (Valid combinations: $COMBINATIONS)"
  echo "Required env variables:"
  echo "  KUBECONFIG:    Specifies the cluster to use"
  echo "  ARCH:          Specifies which container image suffix to use (either arm64 or amd64)"
  echo "  COST:          Stores an additional cost/hour value, e.g., 1.0"
  echo "  META:          Stores additional metadata about the benchmark run, use it to provide the location, e.g., sjc1 as the Packet datacenter region"
  echo "  BENCHMARKNODE: Specifies the node where the benchmark work load runs on."
  echo "  FIXEDX86NODE:  Specifies the node used as client to for network benchmarks. It should be the same x86 hardware for all clusters."
  echo "Optional env variables:"
  echo "  ITERATIONS=1:                   Number of runs inside a Job"
  echo "  NETWORK=\"iperf3 ab fortio\":     Space-separated list of network benchmarks to run (limited to the named ones)"
  echo "  MEMTIER=\"memcached redis\":      Space-separated list of memtier benchmarks to run (limited to the named ones)"
  echo "  SYSBENCH=\"fileio mem cpu\":      Space-separated list of sysbench benchmarks to run (limited to the named ones)"
  echo "  STRESSNG=\"(default in source)\": Space-separated list of stress-ng benchmarks to run (accepts any valid names)"
  echo "                                  To disable sysbench or stress-ng benchmarks set them to a whitespace string but not"
  echo "                                  an empty string. E.g., STRESSNG=\" \" SYSBENCH=\" \" disables both."
  echo "The benchmark results are stored in the cluster as long as the jobs are not cleaned-up."
  echo "The gather process exports them to local files and combines the result with any existing local files."
  echo "Therefore, the intended usage is to gather the results for various clusters into one directory."
  echo "By keeping the cleanup process of Jobs in the cluster optional, multiple clients can access the results without sharing the CSV files."
  echo "Old results can be cleaned-up to speed up the gathering and they are included in the plotted graphs as long as their CSV files are still in the current folder."
  exit 0
fi
arg="$1"

filtered="$(echo "$arg"; echo valid)"
for a in benchmark gather plot cleanup $COMBINATIONS; do
  filtered="$(echo "$filtered" | grep -v "^$a$")"
done
if [ "$filtered" != "valid" ]; then
  echo "ERROR: Unknown argument"; exit 1
fi

ITERATIONS="${ITERATIONS-1}"

if [ "$arg" != "plot" ]; then
  # Test if required env variables are set
  echo "$KUBECONFIG $ARCH $COST $META $BENCHMARKNODE $FIXEDX86NODE" > /dev/null
  # Log them for the user for awareness
  echo "KUBECONFIG=\"$KUBECONFIG\" ARCH=\"$ARCH\" COST=\"$COST\" META=\"$META\" ITERATIONS=\"$ITERATIONS\" BENCHMARKNODE=\"$BENCHMARKNODE\" FIXEDX86NODE=\"$FIXEDX86NODE\""
fi

STRESSNG="${STRESSNG-spawn hsearch crypt atomic tsearch qsort shm sem lsearch bsearch vecmath matrix memcpy}"
SYSBENCH="${SYSBENCH-fileio mem cpu}"
MEMTIER="${MEMTIER-memcached redis}"
NETWORK="${NETWORK-iperf3 ab fortio}"

# List of benchmarks: JOBTYPE,JOBNAME,PARAMETER,RESULT
# Warning, $JOBTYPE$JOBNAME$PARAMETER should not be a valid prefix for another because of globbing.
VARS=()
for S in $MEMTIER; do
  VARS+=("$(printf 'memtier,%s,$ONE,Total-Ops/sec' "$S")" "$(printf 'memtier,%s,$CORES/2,Total-Ops/sec' "$S")" "$(printf 'memtier,%s,$CPUS/2,Total-Ops/sec' "$S")")
done
for S in $STRESSNG; do
  VARS+=("$(printf 'stress-ng,%s,$ONE,bogo-ops/s' "$S")" "$(printf 'stress-ng,%s,$CORES,bogo-ops/s' "$S")" "$(printf 'stress-ng,%s,$CPUS,bogo-ops/s' "$S")")
done
for S in $SYSBENCH; do
  if [ "$S" = cpu ]; then
    COL="Events/s"
  else
    COL="MiB/sec"
  fi
  VARS+=("$(printf 'sysbench,%s,$ONE,%s' "$S" "$COL")" "$(printf 'sysbench,%s,$CORES,%s' "$S" "$COL")" "$(printf 'sysbench,%s,$CPUS,%s' "$S" "$COL")")
done
# Do not use CPUS and CORES here which now refer to the fixed x86 system (which may be correct but rather use fixed numbers here to avoid confusion)
for S in $NETWORK; do
  if [ "$S" = iperf3 ]; then
    VARS+=('iperf3,iperf3,-P 1 -R,MBit/s' 'iperf3,iperf3,-P 28 -R,MBit/s' 'iperf3,iperf3,-P 56 -R,MBit/s')
  elif [ "$S" = ab ]; then
    VARS+=('ab,nginx,56,HTTP-Req/s')
  elif [ "$S" = fortio ]; then
    VARS+=('fortio,fortio,-c 20 -qps=2000 -t=60s,p999 latency ms' 'fortio,fortio,-grpc -s 10 -c 20 -qps=2000 -t=60s,p999 latency ms')
  fi
done
VARS+=("")

if [ "$(echo "$arg" | grep benchmark)" != "" ]; then
  echo "Deploying helpers"
  kubectl apply -f "${script_dir}"/helpers.yaml
  count=0; while [ "x${VARS[count]}" != "x" ]; do
    IFS=, read -r JOBTYPE JOBNAME PARAMETER RESULT <<< "${VARS[count]}"
    BENCHNODESELECTOR="$BENCHMARKNODE"
    BENCHARCH="$ARCH"
    if [ "$JOBTYPE" = iperf3 ] || [ "$JOBTYPE" = ab ] || [ "$JOBTYPE" = fortio ]; then
      # Run the benchmark client on the FIXEDX86NODE and the server on the BENCHMARKNODE
      BENCHNODESELECTOR="$FIXEDX86NODE"
      BENCHARCH=amd64
      NETNODESELECTOR="$BENCHMARKNODE"
      if [ "$JOBNAME" = nginx ]; then
        PORT=8000
      elif [ "$JOBNAME" = iperf3 ]; then
        PORT=6000
      elif [ "$JOBNAME" = fortio ]; then
        if echo "$PARAMETER" | grep grpc > /dev/null; then
          PORT=8079
        else
          PORT=8080
        fi
      else
        echo "Unknown JOBNAME"
        exit 1
      fi
      export ARCH JOBNAME PORT NETNODESELECTOR
      cat "${script_dir}"/network-server.envsubst | envsubst '$ARCH $JOBNAME $PORT $NETNODESELECTOR' | kubectl apply -f -
    fi
    MODE="$JOBNAME"
    ID="$(date +%s%4N | tail -c +5)-$RANDOM"
    PARAMETERQUOTE="$(echo "$PARAMETER" | sed -e 's/\$//' | sed -e 's/\///' | sed -e 's/ //g' | sed -e 's/=//g' | tr '[:upper:]' '[:lower:]')"
    echo "starting $JOBTYPE-$JOBNAME-$PARAMETERQUOTE-$ID"
    PREVARCH="$ARCH"
    ARCH="$BENCHARCH"
    export BENCHNODESELECTOR JOBTYPE MODE ID PARAMETER PARAMETERQUOTE RESULT ARCH COST META ITERATIONS
    # Here "export" is needed so that the envubst process can see the variables
    cat "$script_dir/k8s-job.envsubst" | envsubst '$BENCHNODESELECTOR $JOBTYPE $MODE $ID $PARAMETER $PARAMETERQUOTE $RESULT $ARCH $COST $META $ITERATIONS' | kubectl apply -f -
    ARCH="$PREVARCH"
    export ARCH
    while true; do
      status="$(kubectl get job -n benchmark "$JOBTYPE-$JOBNAME-$PARAMETERQUOTE-$ID" --output=jsonpath='{.status.conditions[0].type}')"
      if [ "$status" = Complete ]; then
        break
      elif [ "$status" = Failed ]; then
        echo "ERROR: Job failed:"
        kubectl get job -n benchmark "$JOBTYPE-$JOBNAME-$PARAMETERQUOTE-$ID"
        exit 1
      fi
      sleep 1
    done
    if [ "$JOBTYPE" = iperf3 ] || [ "$JOBTYPE" = ab ] || [ "$JOBTYPE" = fortio ]; then
      cat "${script_dir}"/network-server.envsubst | envsubst '$ARCH $JOBNAME $PORT $NETNODESELECTOR' | kubectl delete -f -
    fi
    echo "finished $JOBTYPE-$JOBNAME-$PARAMETERQUOTE"
  count=$(( $count + 1 ))
  done
  echo "done with benchmarking"
fi
if [ "$(echo "$arg" | grep gather)" != "" ]; then
  count=0; while [ "x${VARS[count]}" != "x" ]; do
    IFS=, read -r JOBTYPE JOBNAME PARAMETER RESULT <<< "${VARS[count]}"
    PARAMETERQUOTE="$(echo "$PARAMETER" | sed -e 's/\$//' | sed -e 's/\///' | sed -e 's/ //g' | sed -e 's/=//g' | tr '[:upper:]' '[:lower:]')"
    jobs="$(kubectl get jobs -n benchmark --selector=app="$JOBTYPE-$JOBNAME-$PARAMETERQUOTE" --output=jsonpath='{.items[*].metadata.name}')"
    for j in $jobs; do
      kubectl logs -n benchmark "$(kubectl get pods -n benchmark --selector=job-name="$j" --output=jsonpath='{.items[*].metadata.name}')" |  grep --binary-files=text '^CSV:' | cut -d : -f 2- > "$j$ARCH.csv"
    done
  count=$(( $count + 1 ))
  done
  echo "done gathering"
fi
if [ "$(echo "$arg" | grep plot)" != "" ]; then
  count=0; while [ "x${VARS[count]}" != "x" ]; do
    IFS=, read -r JOBTYPE JOBNAME PARAMETER RESULT <<< "${VARS[count]}"
    PARAMETERQUOTE="$(echo "$PARAMETER" | sed -e 's/\$//' | sed -e 's/\///' | sed -e 's/ //g' | sed -e 's/=//g' | tr '[:upper:]' '[:lower:]')"
	{ 	"$script_dir/plot" --parameter --outfile="$JOBTYPE-$JOBNAME-$PARAMETERQUOTE.svg" "$RESULT" "$JOBTYPE-$JOBNAME-$PARAMETERQUOTE"*csv
    	"$script_dir/plot" --parameter --outfile="$JOBTYPE-$JOBNAME-$PARAMETERQUOTE.png" "$RESULT" "$JOBTYPE-$JOBNAME-$PARAMETERQUOTE"*csv
    	"$script_dir/plot" --cost --parameter --outfile="$JOBTYPE-$JOBNAME-$PARAMETERQUOTE-cost.svg" "$RESULT" "$JOBTYPE-$JOBNAME-$PARAMETERQUOTE"*csv
    	"$script_dir/plot" --cost --parameter --outfile="$JOBTYPE-$JOBNAME-$PARAMETERQUOTE-cost.png" "$RESULT" "$JOBTYPE-$JOBNAME-$PARAMETERQUOTE"*csv ; } &
  count=$(( $count + 1 ))
  done
  wait
  echo "done plotting"
fi
if [ "$(echo "$arg" | grep cleanup)" != "" ]; then
  count=0; while [ "x${VARS[count]}" != "x" ]; do
    IFS=, read -r JOBTYPE JOBNAME PARAMETER RESULT <<< "${VARS[count]}"
    PARAMETERQUOTE="$(echo "$PARAMETER" | sed -e 's/\$//' | sed -e 's/\///' | sed -e 's/ //g' | sed -e 's/=//g' | tr '[:upper:]' '[:lower:]')"
    jobs="$(kubectl get jobs -n benchmark --selector=app="$JOBTYPE-$JOBNAME-$PARAMETERQUOTE" --output=jsonpath='{.items[*].metadata.name}')"
    for j in $jobs; do
      kubectl delete job -n benchmark "$j"
    done
  count=$(( $count + 1 ))
  done
  kubectl delete -f "${script_dir}"/helpers.yaml || true
  echo "done with cleanup"
fi
