# This script has no hashbang as it's intended to run on systems with ash or
# bash, including busybox.
set -eu

. /usr/local/bin/output.sh

usage() {
  cat <<EOF
Usage: run-benchmark.sh [-h] [-v] [-T target_host] [-t threads] [-d duration] [--grpc]
                        $(output_options_short)

Run the fortio benchmark

Available options:

-h, --help       Print this help and exit
-v, --verbose    Print script debug info
-T, --target     Name of the host to target for the benchmark (default: fortio-service)
-t, --threads    Amount of threads to use
-d, --duration   Time window to use for the benchmark (default: 60s)
-g, --grpc       Use GRPC for the benchmark
$(output_options_long)
EOF
  exit
}

parse_params() {
  RESULT="p999 latency ms"
  TARGET="fortio-service"
  THREADS=1
  DURATION="60s"
  GRPC="0"

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
    -g | --grpc)
      GRPC="1"
      ;;
    *) ;; # Skip unknown params
    esac
    shift
  done
}

parse_params "$@"

cd /tmp
if [ $GRPC = "1" ]; then
  PORT=8079
  PARAMS="-grpc -s 10 "
else
  PORT=8080
  PARAMS=""
fi

while ! echo | nc "$TARGET" "$PORT"; do
  echo "Waiting for $TARGET:$PORT to be ready..."
  sleep 1
done

while ! echo | nc "$TARGET" 9999 > /tmp/system-out; do
  sleep 1
done

SYSTEM="$(cat /tmp/system-out)"
BENCHMARK_NAME="fortio"
PARAMS="$PARAMS-c $THREADS -t=$DURATION -qps=2000"

output_header

for i in $(seq 1 $ITERATIONS); do
  REQ_BODY_LEN=50
  rm out.json || true
  fortio load $PARAMS -payload-size=50 -keepalive=false \
          -labels='-payload-size=50 -keepalive=false $PARAMS Iteration: '"$i" \
          -json=out.json "http://$TARGET:$PORT"
  cat out.json > /dev/stderr
  VALUE=$(cat /tmp/out.json | jq '.DurationHistogram.Percentiles[-1].Value*1000')
  output_line "$VALUE"
done
