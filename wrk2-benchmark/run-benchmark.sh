# This script has no hashbang as it's intended to run on systems with ash or
# bash, including busybox.
set -eu

. /usr/local/bin/output.sh

usage() {
  cat <<EOF
Usage: run-benchmark.sh [-h] [-v] [-T target_host] [-t threads] [-d duration]
                        $(output_options_short)

Run the wrk2 benchmark

Available options:

-h, --help       Print this help and exit
-v, --verbose    Print script debug info
-T, --target     Name of the host to target for the benchmark (default: wrk2-service)
-t, --threads    Amount of threads and connections to use
$(output_options_long)
EOF
  exit
}

parse_params() {
  RESULT="p999 latency ms"
  TARGET="wrk2-service"
  THREADS=1
  DURATION="60s"

  parse_output_params "$@"
  set -- $UNPARSED

  while [ $# -gt 0 ]; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    -T | --target)
      TARGET="${2-}"
      shift
      ;;
    -t | --threads)
      THREADS="${2-}"
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

PORT=9000
MODE=nginx

while ! echo | nc "$TARGET" "$PORT"; do
  echo "Waiting for $TARGET:$PORT..."
  sleep 1
done

while ! echo | nc "$TARGET" 9999 > /tmp/system-out; do
  sleep 1
done

SYSTEM="$(cat /tmp/system-out)"
BENCHMARK_NAME="wrk2 $MODE"
PARAMS="-d $DURATION -c $THREADS -t $THREADS (body 100B)"

output_header

for i in $(seq 1 $ITERATIONS); do
  LATENCY="$(wrk -d $DURATION -c $THREADS -t $THREADS -R 2000 -L -s /usr/local/share/wrk2/body-100-report.lua "http://$TARGET:$PORT" | tee /dev/stderr | grep 99.900% | awk '{print $2}')"
  # cut away unit (ms or s)
  if echo "$LATENCY" | grep ms > /dev/null; then
    U=m
  else
    U=s
  fi
  LATENCY="$(echo $LATENCY | cut -d "$U" -f 1)"
  # calculate ms if unit was s
  if [ "$U" = s ]; then
    LATENCY="$(awk "BEGIN{print "$LATENCY"*1000}")"
  fi
  output_line "$LATENCY"
done
