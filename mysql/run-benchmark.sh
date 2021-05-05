# This script has no hashbang as it's intended to run on systems with ash or
# bash, including busybox.
set -eu

. /usr/local/bin/output.sh

usage() {
  cat <<EOF
Usage: run-benchmark.sh [-h] [-v] [-y benchmark_type] [-t threads]
                        $(output_options_short)

Run the sysbench benchmark

Available options:

-h, --help       Print this help and exit
-v, --verbose    Print script debug info
-t, --threads    Amount of threads to use for the benchmark (default: 1)
$(output_options_long)
EOF
  exit
}

parse_params() {
  TYPE=""
  THREADS=1

  parse_output_params "$@"
  set -- $UNPARSED

  while [ $# -gt 0 ]; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    -t | --threads)
      THREADS="${2-}"
      shift
      ;;
    *) ;; # Skip unknown params
    esac
    shift
  done
}

parse_params "$@"

THREADS=${THREADS}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_ITERATIONS=${MYSQL_ITERATIONS}
PUSHGATEWAY_URL=${PUSHGATEWAY_URL}
CLOUD=${CLOUD}
INSTANCE=${INSTANCE}
JOBNAME=${JOBNAME}

SYSTEM=$(/usr/local/bin/cpu.sh system)
PARAMS="--threads=$THREADS"

echo "Starting the database server..."
# Run the mysql server
/usr/local/bin/run-server.sh "${MYSQL_DATABASE}" &

# Check connection to mysql
until mysql -u root -e ";" ; do
  sleep 1
  echo "Waiting for DB to start..."
done

cd /tmp

echo "Creating json conversion file."

cat >output_json.lua <<EOF
ffi.cdef[[int usleep(unsigned int);]]

function event()
  ffi.C.usleep(1000)
end

sysbench.hooks.report_intermediate = sysbench.report_json
EOF

echo "This is iterations $MYSQL_ITERATIONS"
for I in $(seq 1 $MYSQL_ITERATIONS); do
  ts=$(date -Iseconds | sed -e 's/T/__/' -e 's/+.*//')
  echo "Preparing benchmark"
  sysbench $PARAMS --db-driver=mysql --mysql-user=root --tables=16 --table-size=10000 --mysql-db="$MYSQL_DATABASE" /usr/local/share/sysbench/oltp_read_write.lua prepare

  echo "Running benchmark"
  sysbench $PARAMS --db-driver=mysql --mysql-user=root --tables=16 --table-size=10000 --mysql-db="$MYSQL_DATABASE" --time=5 --report-interval=1 --verbosity=5 --rate=40 --events=0 /tmp/output_json.lua run > /tmp/output-$I.txt

  echo "Running cleanup"
  sysbench $PARAMS --db-driver=mysql --mysql-user=root --tables=16 --table-size=10000 --mysql-db="$MYSQL_DATABASE" /usr/local/share/sysbench/oltp_read_write.lua cleanup

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

  cat <<EOF | curl --data-binary @- $PUSHGATEWAY_URL/metrics/job/$JOBNAME/cloud/$CLOUD/instance/$INSTANCE/run/$ts

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
done

killall mysqld || true
