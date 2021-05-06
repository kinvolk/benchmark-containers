#!/bin/sh
set -eu

. /usr/local/bin/output.sh

usage() {
  cat <<EOF
Usage: run-benchmark.sh [-h] [-v] [-y benchmark_type] [-t threads]
                        $(output_options_short)

Run the memtier benchmark

Available options:

-h, --help       Print this help and exit
-v, --verbose    Print script debug info
-y, --type       Type of benchmark to run (memcached, redis). Optionally a semicolon separated list.
-t, --threads    Amount of threads to use for the benchmark (default: 1). Optionally a semicolon separated list.
$(output_options_long)
EOF
  exit
}

parse_params() {
  RESULT="Total ops/sec"
  TYPE="memcached"
  THREADS=1

  parse_output_params "$@"
  set -- $UNPARSED

  while [ $# -gt 0 ]; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    -y | --type)
      ARG_TYPE="${2-}"
      shift
      ;;
    -t | --threads)
      ARG_THREADS="${2-}"
      shift
      ;;
    *) ;; # Skip unknown params
    esac
    shift
  done
}

parse_params "$@"

start_server() {
  if [ "$TYPE" = "memcached" ]; then
    # When benchmarking memcached, use half as many more threads as those being
    # used by the server.
    BENCHMARKTHREADS=$(($THREADS+$THREADS/2))
    BENCHMARKPROCESSES=1
    CONCURRENCYTYPE=threads
    PROTOCOL=memcache_binary
    memcached --port "$(( PORT + 1 ))" -u "$(whoami)" -t "$THREADS" &
  else
    BENCHMARKTHREADS=1
    BENCHMARKPROCESSES="$THREADS"
    CONCURRENCYTYPE=processes
    PROTOCOL=redis
    for P in $(seq 1 $BENCHMARKPROCESSES); do
      redis-server --port "$(( PORT + P ))" &
    done
  fi
  
  echo "Using $THREADS $CONCURRENCYTYPE for the database"
  for P in $(seq 1 $BENCHMARKPROCESSES); do
    while [ "$(wget "http://127.0.0.1:$(( PORT + P ))" 2>&1 | grep "Connection refused")" != "" ]; do
      sleep 1
      echo "Waiting for DB $P to start..."
    done
  done
}

benchmark() {
  SYSTEM=$(/usr/local/bin/cpu.sh system)
  BENCHMARK_NAME="memtier_$TYPE"
  PARAMS="$CONCURRENCYTYPE=$THREADS"
  output_header

  echo "Using $BENCHMARKPROCESSES processes and $BENCHMARKTHREADS threads for the benchmark client"
  for I in $(seq 1 $ITERATIONS); do
    WAIT=""
    for P in $(seq 1 $BENCHMARKPROCESSES); do
      { memtier_benchmark -p "$(( PORT + P ))" -P "$PROTOCOL" -t "$BENCHMARKTHREADS" --test-time 30 --pipeline=100 --ratio 1:1 -c 25 -x 1 --data-size-range=10240-1048576 --key-pattern S:S --json-out-file=$I-$P.json 2>&1 | tee /dev/stderr | grep Totals | tail -n 1 | awk '{print $2}' | cut -d . -f 1 > "$P" ; } &
      WAIT="$WAIT""$! "
    done
    wait $WAIT
    SUM=0
    for P in $(cat $(seq 1 $BENCHMARKPROCESSES)); do
      SUM="$(( SUM + P ))"
    done
    # Pushing metrics to pushgateway.
    TS=$(date -Iseconds | sed -e 's/T/__/' -e 's/+.*//')
    for P in $(seq 1 $BENCHMARKPROCESSES); do
      RUN_ID="$TS/process/$P"
      read -d '' metrics <<EOF || true
          # TYPE memtier_run_information_ gauge
          $(cat /tmp/$I-$P.json | jq -r '."run information" | to_entries | .[] | "memtier_run_information_"+ (.key|ascii_downcase|gsub("\\s";"_")) + " " + (.value|tostring)')

          # TYPE memtier_all_stats_sets_ gauge
          $(cat /tmp/$I-$P.json | jq -r '."ALL STATS".Sets | to_entries | .[] | "memtier_all_stats_sets_"+ (.key|ascii_downcase|gsub("/";"_")) + " " + (.value|tostring)')

          # TYPE memtier_all_stats_gets_ gauge
          $(cat /tmp/$I-$P.json | jq -r '."ALL STATS".Gets | to_entries | .[] | "memtier_all_stats_gets_"+ (.key|ascii_downcase|gsub("/";"_")) + " " + (.value|tostring)')

          # TYPE memtier_all_stats_waits_ gauge
          $(cat /tmp/$I-$P.json | jq -r '."ALL STATS".Waits | to_entries | .[] | "memtier_all_stats_waits_"+ (.key|ascii_downcase|gsub("/";"_")) + " " + (.value|tostring)')

          # TYPE memtier_all_stats_totals_ gauge
          $(cat /tmp/$I-$P.json | jq -r '."ALL STATS".Totals | to_entries | .[] | "memtier_all_stats_totals_"+ (.key|ascii_downcase|gsub("/";"_")) + " " + (.value|tostring)')

          # TYPE memtier_request_latency_distribution_set gauge
          $(cat /tmp/$I-$P.json | jq -r '."ALL STATS".SET | .[] | "memtier_request_latency_distribution_set{msec=" + "\"" + (."<=msec"|tostring) + "\"" + "}" + " " + (.percent|tostring)')

          # TYPE memtier_request_latency_distribution_get gauge
          $(cat /tmp/$I-$P.json | jq -r '."ALL STATS".GET | .[] | "memtier_request_latency_distribution_get{msec=" + "\"" + (."<=msec"|tostring) + "\"" + "}" + " " + (.percent|tostring)')
EOF
      push_metrics "$metrics"
    done
    output_line "$SUM"
  done
}

cleanup() {
  killall redis-server memcached || true
  sleep 5 # Wait for the servers to actually finish
}

cd /tmp
PORT=7000

for TYPE in ${ARG_TYPE//;/ } ; do
  echo "Running for type ${TYPE}"
  for THREADS in ${ARG_THREADS//;/ }; do
    echo "Running for threads ${THREADS}"
    start_server
    benchmark
    cleanup
  done
done
