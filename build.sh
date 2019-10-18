#!/bin/bash
# Docker build helper to build one, or multiple, benchmark container(s)

targets="fio stress-ng sysbench"
cmdl_targets=""

build_root=$(dirname "${BASH_SOURCE[0]}")

while [ 0 -lt $# ]; do
	[ -d "$1" ] && cmdl_targets="$cmdl_targets $1"
	shift
done

[ -n "$cmdl_targets" ] && targets="$cmdl_targets"

echo "#############  Building: $targets  ###############"

for t in $targets; do
	echo "----------------- $t -----------------"
	cp ${build_root}/common/dstat-types.patch "${build_root}/$t/"
	cd "${build_root}/$t"
	tag=$(basename "$t")
	docker build -t "$tag" .
	rm dstat-types.patch
	cd -
done

echo "#############  DONE: $targets  ###############"
