#!/bin/bash
# Docker build helper to build one, or multiple, benchmark container(s)

targets="fio stress-ng sysbench iperf3 memtier nginx ab fortio wrk2-benchmark"
cmdl_targets=""

build_root=$(dirname "${BASH_SOURCE[0]}")

while [ 0 -lt $# ]; do
	if [ -d "$1" ] ; then
		cmdl_targets="$cmdl_targets $1"
	else
		echo " ## ERROR - Unsupported build target: $1" >&2
		echo " ## Supported targets are: $targets" >&2
		exit 1
	fi
	shift
done

[ -n "$cmdl_targets" ] && targets="$cmdl_targets"

echo "#############  Building dependencies - dstat ###############"
docker build -t dstat-builder "${build_root}/dstat"

echo "#############  Building: $targets  ###############"

for t in $targets; do
	echo "----------------- $t -----------------"
	tag=$(basename "$t")
	docker build -t "$tag" "${build_root}/$t"
done

echo "#############  DONE: $targets  ###############"
