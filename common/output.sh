# This script has no hashbang as it's intended to run on systems with ash or
# bash, including busybox.
set -eu

output_options_short() {
  echo "[-i iterations] [-r result] [-j job_id] [-c cost] [-m metadata]"
}

output_options_long() {
  cat <<EOF
-i, --iterations Number of iterations to run
-r, --result     Name of the result column
-j, --job-id     Job identifier
-c, --cost       Cost/hour value
-m, --metadata   Metadata related to the benchmark
EOF
  exit
}

parse_output_params() {
  ITERATIONS=1
  RESULT="${RESULT-}"
  ID=""
  COST=""
  META=""
  UNPARSED=""

  while [ $# -gt 0 ]; do
    case "${1-}" in
    -i | --iterations)
      ITERATIONS="${2-}"
      shift
      ;;
    -r | --result)
      RESULT="${2-}"
      shift
      ;;
    -j | --job-id)
      ID="${2-}"
      shift
      ;;
    -c | --cost)
      COST="${2-}"
      shift
      ;;
    -m | --metadata)
      META="${2-}"
      shift
      ;;
    *) # Keep unknown params to have them be parsed by other functions
      UNPARSED="$UNPARSED $1"
      ;;
    esac
    shift
  done
}

output_header() {
  echo
  echo "CSV:Name,Parameter,System,$RESULT,Job,Cost,Meta"
}

output_line() {
  VALUE=$1
  echo "CSV:$BENCHMARK_NAME,$PARAMS,$SYSTEM,$VALUE,$ID,$COST,$META"
}
