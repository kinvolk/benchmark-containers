#!/bin/bash
set -euo pipefail

if [ "$#" != 2 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: NORMALIZATIONSYSTEM=… $0 FILE ARG"
  echo "Runs 'benchmark.sh ARG' for each cluster entry in FILE."
  echo "NORMALIZATIONSYSTEM is a global environment variable that is passed to benchmark.sh"
  echo "FILE contains one cluster entry per line, stored as comma-separated values"
  echo "(no whitespaces before or after comma) in the following order:"
  echo "KUBECONFIG,ARCH,COST,META,ITERATIONS,BENCHMARKNODE,FIXEDX86NODE"
  echo "The values are used as env vars for benchmark.sh."
  echo "A final 'benchmark.sh plot' run is done if 'gather' is part of ARG."
  echo
  echo "The env vars SYSBENCH and STRESSNG accept a space-separated list of"
  echo "benchmarks (currently limited for SYSBENCH but generic for STRESSNG)."
  exit 0
fi
FILE="$1"
ARG="$2"

echo "$NORMALIZATIONSYSTEM" > /dev/null

# Assuming that benchmark.sh is in the same folder as this script
P="$(dirname "$(readlink -f $(which "$0"))")"

WAIT=""
while IFS= read -r line || [ -n "$line" ]; do
  IFS=, read KUBECONFIG ARCH COST META ITERATIONS BENCHMARKNODE FIXEDX86NODE <<< "$line"
  export KUBECONFIG ARCH COST META ITERATIONS BENCHMARKNODE FIXEDX86NODE NORMALIZATIONSYSTEM
  "$P/benchmark.sh" "$ARG" &
  WAIT+="$! "
  if [ "$ARG" = plot ]; then
    break  # running once is enough
  fi
done < "$FILE"

wait $WAIT

if [ "$(echo "$ARG" | grep gather)" != "" ] && [ "$ARG" != cleanup ]; then
  "$P/benchmark.sh" plot
fi
