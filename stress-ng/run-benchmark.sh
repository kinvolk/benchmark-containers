# This script has no hashbang as it's intended to run on systems with ash or
# bash, including busybox.
set -eu

. /usr/local/bin/output.sh

usage() {
  cat <<EOF
Usage: run-benchmark.sh [-h] [-v] [-y benchmark_type] [-t threads]
                        $(output_options_short)

Run the stress-ng benchmark

Available options:

-h, --help       Print this help and exit
-v, --verbose    Print script debug info
-y, --type       Type of stressor to run (spawn, hsearch, etc)
-t, --threads    Amount of threads to use for the benchmark (default: 1)
$(output_options_long)
EOF
  exit
}

parse_params() {
  RESULT="bogo-ops/s"
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
BENCHMARK_NAME="stress-ng $TYPE"
PARAMS="threads=$THREADS"

output_header

cd /tmp
for i in $(seq 1 $ITERATIONS); do
  VALUE=$(stress-ng --$TYPE $THREADS --timeout 30s --metrics-brief 2>&1 | grep $TYPE | tail -n 1 | awk '{print $9}')
  output_line "$VALUE"
done
