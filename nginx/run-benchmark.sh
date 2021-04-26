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
  DURATION="10s"
  CONNECTIONS=400

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
    -c | --connections)
      CONNECTIONS="${2-}"
      shift
      ;;
    -d | --duration)
      DURATION="${2-}"
      shift
      ;;
    *) ;; # Skip unknown params
    esac
    shift
  done
}

parse_params "$@"

THREADS=${THREADS}
CONNECTIONS=${CONNECTIONS}
DURATION=${DURATION}
NGINX_ITERATIONS=${NGINX_ITERATIONS}
PUSHGATEWAY_URL=${PUSHGATEWAY_URL}
CLOUD=${CLOUD}
INSTANCE=${INSTANCE}
JOBNAME=${JOBNAME}

SYSTEM=$(/usr/local/bin/cpu.sh system)
PARAMS="-d $DURATION -c $CONNECTIONS -t $THREADS"

# starts nginx
echo "Starting nginx"
nginx

echo "This is iterations $NGINX_ITERATIONS"
for I in $(seq 1 $NGINX_ITERATIONS); do
  echo "I came here $I."
  ts=$(date -Iseconds | sed -e 's/T/__/' -e 's/+.*//')
  # Run benchmark and save output to a file
  wrk ${PARAMS} -s /usr/local/share/wrk/report-json.lua -L http://127.0.0.1:8000/ > /tmp/output-$I.txt

  # Scrape metrics from the file
  latency_avg=$(cat /tmp/output-$I.txt | grep "Latency Avg" | cut -d":" -f2 | xargs)
  requests_sec=$(cat /tmp/output-$I.txt | grep "Requests/sec" | cut -d":" -f2 | xargs)
  transfer_sec=$(cat /tmp/output-$I.txt | grep "Transfer/sec" | cut -d":" -f2 | cut -d"M" -f1 | xargs)
  total_requests=$(cat /tmp/output-$I.txt | grep "Total Requests" | cut -d":" -f2 | xargs)
  http_errors=$(cat /tmp/output-$I.txt | grep "HTTP errors" | cut -d":" -f2 | xargs)
  request_timed_out=$(cat /tmp/output-$I.txt | grep "Requests timed out" | cut -d":" -f2 | xargs)
  bytes_received=$(cat /tmp/output-$I.txt | grep "Bytes received" | cut -d":" -f2 | xargs)
  socket_connect_errors=$(cat /tmp/output-$I.txt | grep "Socket connect errors" | cut -d":" -f2 | xargs)
  socket_read_errors=$(cat /tmp/output-$I.txt | grep "Socket read errors" | cut -d":" -f2 | xargs)
  socket_write_errors=$(cat /tmp/output-$I.txt | grep "Socket write errors" | cut -d":" -f2 | xargs)

  cat <<EOF | curl --data-binary @- $PUSHGATEWAY_URL/metrics/job/$JOBNAME/cloud/$CLOUD/instance/$INSTANCE-$I/run/$ts

    # TYPE nginx_latency_avg gauge
    $(echo "nginx_latency_avg ${latency_avg}")

    # TYPE nginx_requests_sec gauge
    $(echo "nginx_requests_sec ${requests_sec}")

    # TYPE nginx_transfer_sec gauge
    $(echo "nginx_transfer_sec ${transfer_sec}")

    # TYPE nginx_total_requests gauge
    $(echo "nginx_total_requests ${total_requests}")

    # TYPE nginx_http_errors gauge
    $(echo "nginx_http_errors ${http_errors}")

    # TYPE nginx_request_timed_out gauge
    $(echo "nginx_request_timed_out ${request_timed_out}")

    # TYPE nginx_bytes_received gauge
    $(echo "nginx_bytes_received ${bytes_received}")

    # TYPE nginx_socket_ gauge
    $(echo "nginx_socket_connect_errors ${socket_connect_errors}")
    $(echo "nginx_socket_read_errors ${socket_read_errors}")
    $(echo "nginx_socket_write_errors ${socket_write_errors}")
EOF
done

