# This script has no hashbang as it's intended to run on systems with ash or
# bash, including busybox.
set -eu

output_options_short() {
  echo "[-i iterations] [-r result] [-j job_name] [-c cost] [-m metadata]"
  echo "[-I instance_type] [-C cloud_platform] [-P push_gateway_url]"
}

output_options_long() {
  cat <<EOF
-i, --iterations   Number of iterations to run
-r, --result       Name of the result column
-j, --job-name     Job name identifier
-c, --cost         Cost/hour value
-I, --instance     Instance type
-C, --cloud        Cloud platform
-P, --push-gateway URL of the Push Gateway
-m, --metadata     Metadata related to the benchmark
EOF
  exit
}

parse_output_params() {
  ITERATIONS=1
  RESULT="${RESULT-}"
  ID=""
  COST=""
  META=""
  CLOUD=""
  INSTANCE=""
  PUSHGATEWAY_URL=""
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
    -I | --instance)
      INSTANCE="${2-}"
      shift
      ;;
    -C | --cloud)
      CLOUD="${2-}"
      shift
      ;;
    -P | --push-gateway)
      PUSHGATEWAY_URL="${2-}"
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

push_metrics() {
  VALUE="$1"
  if [[ -n "$PUSHGATEWAY_URL" ]]; then
    METRICS_URL="$PUSHGATEWAY_URL/metrics/job/$BENCHMARK_NAME/cloud/$CLOUD/instance/$INSTANCE/run/$RUN_ID"
    echo "Pushing metrics to: $METRICS_URL"
    echo "$VALUE" | curl --data-binary @- "$METRICS_URL"
  fi
}
