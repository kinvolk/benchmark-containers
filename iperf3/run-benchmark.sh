# This script has no hashbang as it's intended to run on systems with ash or
# bash, including busybox.
set -eu

. /usr/local/bin/output.sh

usage() {
  cat <<EOF
Usage: run-benchmark.sh [-h] [-v] [-T target_host] [-t threads]
                        $(output_options_short)

Run the iperf3 benchmark

Available options:

-h, --help       Print this help and exit
-v, --verbose    Print script debug info
-T, --target     Name of the host to target for the benchmark (default: iperf3-service)
-t, --threads    Number of parallel concurrent streams to run
$(output_options_long)
EOF
  exit
}

parse_params() {
  RESULT="MBit/s"
  TARGET="iperf3-service"
  THREADS=1

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
    *) ;; # Skip unknown params
    esac
    shift
  done
}

parse_params "$@"

PORT=6000
MODE=nginx

while ! echo | nc "$TARGET" "$PORT"; do
  echo "Waiting for $TARGET:$PORT..."
  sleep 1
done

while ! echo | nc "$TARGET" 9999 > /tmp/system-out; do
  sleep 1
done

SYSTEM="$(cat /tmp/system-out)"
BENCHMARK_NAME="iperf3 $MODE"
PARAMS="$THREADS"

output_header

for i in $(seq 1 $ITERATIONS); do
  VALUE=$(iperf3 -p "$PORT" -P $THREADS -R -c $TARGET --time 30 -J | tee /dev/stderr | jq '.end.sum_received.bits_per_second/(1000*1000)')
  output_line "$VALUE"
done
