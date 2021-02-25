# This script has no hashbang as it's intended to run on systems with ash or
# bash, including busybox.
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
-y, --type       Type of benchmark to run (memcached, redis)
-t, --threads    Amount of threads to use for the benchmark (default: 1)
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
      TYPE="${2-}"
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

cd /tmp
PORT=7000

if [ "$TYPE" = "memcached" ]; then
  BENCHMARKTHREADS="$THREADS"
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

SYSTEM=$(/usr/local/bin/cpu.sh system)
BENCHMARK_NAME="memtier $TYPE"
PARAMS="$CONCURRENCYTYPE=$THREADS"
output_header

echo "Using $BENCHMARKPROCESSES processes and $BENCHMARKTHREADS threads for the benchmark client"
for I in $(seq 1 $ITERATIONS); do
  WAIT=""
  for P in $(seq 1 $BENCHMARKPROCESSES); do
    { memtier_benchmark -p "$(( PORT + P ))" -P "$PROTOCOL" -t "$BENCHMARKTHREADS" --test-time 30 --ratio 1:1 -c 25 -x 1 --data-size-range=10240-1048576 --key-pattern S:S  2>&1 | tee /dev/stderr | grep Totals | tail -n 1 | awk '{print $2}' | cut -d . -f 1 > "$P" ; } &
    WAIT="$WAIT""$! "
  done
  wait $WAIT
  SUM=0
  for P in $(cat $(seq 1 $BENCHMARKPROCESSES)); do
    SUM="$(( SUM + P ))"
  done
  output_line "$SUM"
done

killall redis-server memcached || true
