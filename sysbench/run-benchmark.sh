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
-y, --type       Type of benchmark to run (mem, cpu, fileio)
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

SYSTEM=$(/usr/local/bin/cpu.sh system)
BENCHMARK_NAME="sysbench $TYPE"
PARAMS="--threads=$THREADS"

if [ "$TYPE" = "fileio" ]; then
  PARAMS="$PARAMS --file-test-mode=rndwr"
fi

output_header

cd /tmp
for i in $(seq 1 $ITERATIONS); do
  if [ "$TYPE" = "mem" ]; then
    VALUE=$(sysbench $PARAMS --time=30 memory --memory-total-size=500G run | tee /dev/stderr | grep 'MiB/sec' | cut -d '(' -f 2 | cut -d ' ' -f 1)
  elif [ "$TYPE" = "cpu" ]; then
    VALUE=$(sysbench $PARAMS --time=30 cpu run | tee /dev/stderr | grep 'events per second' | cut -d : -f 2 | xargs)
  elif [ "$TYPE" = "fileio" ]; then
    sysbench fileio --file-test-mode=rndwr prepare
    VALUE=$(sysbench $PARAMS --time=30 fileio run | tee /dev/stderr | grep 'written, MiB/s' | cut -d : -f 2 | xargs)
  else
    echo "ERROR: Unknown benchmark type"
    exit 1
  fi
  output_line "$VALUE"
done
