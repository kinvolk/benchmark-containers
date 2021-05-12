#!/bin/bash
set -eu

. /usr/local/bin/output.sh
cd /tmp

usage() {
  cat <<EOF
Usage: run-benchmark.sh [-h] [-v] [-t threads] [-d --mysql-db]
                        $(output_options_short)

Run the mysql benchmark

Available options:

-h, --help       Print this help and exit
-v, --verbose    Print script debug info
-t, --threads    Amount of threads to use for the benchmark (default: 1). Optionally a semicolon separated list.
-d, --mysql-db   Database to create in MySQL.
$(output_options_long)
EOF
  exit
}

parse_params() {
  THREADS=1

  parse_output_params "$@"
  set -- $UNPARSED

  while [ $# -gt 0 ]; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    -t | --threads)
      ARG_THREADS="${2-}"
      shift
      ;;
    -d | --mysql-db)
      MYSQL_DATABASE="${2-}"
      shift
      ;;
    *) ;; # Skip unknown params
    esac
    shift
  done
}

start_database() {
  echo "[i] Starting the database server..."

  # Run the mysql server
  /usr/local/bin/run-server.sh "${MYSQL_DATABASE}" &

  trap 'killall mysqld || true' SIGHUP SIGTERM SIGINT EXIT

  # Check connection to mysql
  until mysql -u root --skip-password -e ";" ; do
    sleep 5
    echo "[i] Waiting for DB to start..."
  done

  # Create the database.
  echo "[i] Creating database $MYSQL_DATABASE"
  mysql -u root -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE;"
}

setup_sysbench_config() {
  echo "[i] Creating JSON conversion file."
  cat >output_json.lua <<EOF
ffi.cdef[[int usleep(unsigned int);]]

function event()
  ffi.C.usleep(1000)
end

sysbench.hooks.report_intermediate = sysbench.report_json
EOF
}

benchmark() {

  BENCHMARK_NAME="mysql"
  PARAMS="--threads=$THREADS --db-driver=mysql --mysql-user=root --tables=16 --table-size=1000000 \
    --rand-type=uniform --mysql-db=$MYSQL_DATABASE"

  for I in $(seq 1 $ITERATIONS); do
    ts=$(date -Iseconds | sed -e 's/T/__/' -e 's/+.*//')
    echo "[i] Preparing benchmark"
    sysbench $PARAMS /usr/share/sysbench/oltp_read_write.lua prepare

    echo "[i] Running benchmark"
    sysbench $PARAMS --time=100 --report-interval=1 --verbosity=5 --rate=40 --events=0 \
      /tmp/output_json.lua run > /tmp/output-$I.txt

    echo "[i] Running cleanup"
    sysbench $PARAMS /usr/share/sysbench/oltp_read_write.lua cleanup

    # General Statistics
    total_time=$(cat /tmp/output-$I.txt | grep -A 3 "General statistics" | grep "total time:" |cut -d":" -f2| xargs | cut -d "s" -f1)
    total_events=$(cat /tmp/output-$I.txt | grep -A 3 "General statistics" | grep "total number of events:" |cut -d":" -f2 |xargs)

    # Latency
    latency_min=$(cat /tmp/output-$I.txt | grep -A5 "Latency (ms)" | grep "min:" |cut -d":" -f2 |xargs)
    latency_max=$(cat /tmp/output-$I.txt | grep -A5 "Latency (ms)" | grep "max:" |cut -d":" -f2 |xargs)
    latency_avg=$(cat /tmp/output-$I.txt | grep -A5 "Latency (ms)" | grep "avg:" |cut -d":" -f2 |xargs)
    latency_percentile=$(cat /tmp/output-$I.txt | grep -A5 "Latency (ms)" | grep "percentile:" |cut -d":" -f2 |xargs)
    latency_sum=$(cat /tmp/output-$I.txt | grep -A5 "Latency (ms)" | grep "sum:" |cut -d":" -f2 |xargs)

    # Thread fairness
    thread_fairness_events=$(cat /tmp/output-$I.txt | grep -A2 "Threads fairness" | grep "events" |cut -d":" -f2 |xargs | cut -d "/" -f1)
    thread_fairness_execution_time=$(cat /tmp/output-$I.txt | grep -A2 "Threads fairness" | grep "execution time" |cut -d":" -f2 |xargs | cut -d "/" -f1)

    # JSON data extracted from txt file and converted to json
    sed -n '18,/Time limit exceeded, exiting.../p' /tmp/output-$I.txt | sed 's/Time limit exceeded, exiting...//' | sed '${s/$/]/}' > output-$I.json
    sed -i 's|^DEBUG.*||g; s|^Threads started.*||g' /tmp/output-$I.json

    RUN_ID="$ts/threads/$THREADS"
    read -d '' metrics <<EOF || true
      # TYPE mysql_general_statistics_total_ gauge
      $(echo "mysql_general_statistics_total_time ${total_time}")
      $(echo "mysql_general_statistics_total_events ${total_events}")

      # TYPE mysql_latency_ gauge
      $(echo "mysql_latency_min ${latency_min}")
      $(echo "mysql_latency_max ${latency_max}")
      $(echo "mysql_latency_avg ${latency_avg}")
      $(echo "mysql_latency_percentile ${latency_percentile}")
      $(echo "mysql_latency_sum ${latency_sum}")

      # TYPE mysql_thread_fairness_ gauge
      $(echo "mysql_thread_fairness_events ${thread_fairness_events}")
      $(echo "mysql_thread_fairness_execution_time ${thread_fairness_execution_time}")

      # TYPE mysql_benchmark_result_ gauge
      $(cat /tmp/output-1.json | jq -r '.[] | "mysql_benchmark_result_threads{time="+ "\"" + (.time|tostring) + "\"} " + (.threads|tostring)')
      $(cat /tmp/output-1.json | jq -r '.[] | "mysql_benchmark_result_tps{time="+ "\"" + (.time|tostring) + "\"} " + (.tps|tostring)')
      $(cat /tmp/output-1.json | jq -r '.[] | "mysql_benchmark_result_latency{time="+ "\"" + (.time|tostring) + "\"} " + (.latency|tostring)')
      $(cat /tmp/output-1.json | jq -r '.[] | "mysql_benchmark_result_errors{time="+ "\"" + (.time|tostring) + "\"} " + (.errors|tostring)')
      $(cat /tmp/output-1.json | jq -r '.[] | "mysql_benchmark_result_reconnects{time="+ "\"" + (.time|tostring) + "\"} " + (.reconnects|tostring)')
      $(cat /tmp/output-1.json | jq -r '.[] | "mysql_benchmark_result_qps_total{time="+ "\"" + (.time|tostring) + "\"} " + (.qps.total|tostring)')
      $(cat /tmp/output-1.json | jq -r '.[] | "mysql_benchmark_result_qps_reads{time="+ "\"" + (.time|tostring) + "\"} " + (.qps.reads|tostring)')
      $(cat /tmp/output-1.json | jq -r '.[] | "mysql_benchmark_result_qps_writes{time="+ "\"" + (.time|tostring) + "\"} " + (.qps.writes|tostring)')
      $(cat /tmp/output-1.json | jq -r '.[] | "mysql_benchmark_result_qps_other{time="+ "\"" + (.time|tostring) + "\"} " + (.qps.other|tostring)')
EOF
    push_metrics "$metrics"
  done

}

parse_params "$@"
start_database
setup_sysbench_config


for THREADS in ${ARG_THREADS//;/ }; do
  echo "[i] Running for threads ${THREADS}."
  benchmark
done
