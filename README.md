# benchmark-containers
Benchmark container build files for a variety of cloud-native system-level
benchmarks.

All containers listed below also ship version 0.8.0 of
[dstat](https://github.com/dagwieers/dstat). DStat's CSV output in particular
is a nice way of streaming system metrics.

The containers are based on [Alpine](https://alpinelinux.org/).

Building
========
All benchmark containers ship `dstat`, which is built as a dependency.
We provide a convenience build script for creating container images with this
dependency: `build.sh` in the project root.

Call `./build.sh` without arguments to build all containers in the project, or
`./build.sh <container> [<container>] ...` to build individual containers
(e.g. `./build.sh fio` to just build the Fio container).

**Please note** that the `perf` container currently needs to be built
separately from `./build.sh` as the `perf` build currently contains a number
of workarounds.

fio container
=============
The FIO container ships release 3.15 of the
[Flexible IO tester](https://github.com/axboe/fio).

stress-ng container
===================
The container ships release 0.10.07 of
[stress-ng](https://github.com/ColinIanKing/stress-ng).

sysbench container
==================
The container ships release 1.0.17 of
[sysbench](https://github.com/akopytov/sysbench). The sysbench build includes
support for MariaDB / MySQL benchmarking as well as LUA scripting.

iperf3 container
================
The container ships release 3.7 of [iperf](https://github.com/esnet/iperf/).

perf container
==============
The container ships the version of
[perf](https://perf.wiki.kernel.org/index.php/Main_Page) that belongs to the
Flatcar kernel release the container is built on. Please note that the build is
platform / release specific. Also, the build contains a number of workarounds
compensating for transient shortcomings in the Flatcar SDK.
**Please note** that the build currently needs to be executed on a Flatcar
instance.  We are working on improving the build.

# Kubernetes cluster benchmark
The `cluster-script` folder contains scripts to run the benchmark containers
on Kubernetes clusters and compare the results.

The `run-for-list.sh` script runs the benchmark for all clusters provided in
a configuration file.

The `benchmark.sh` script works on a single cluster per invocation.
It covers automatic creation of K8s Jobs for sysbench cpu and memory benchmarks,
gathering the results as CSV files and plotting them together with previous
results as graphs for comparison.

The benchmark results are stored in the cluster as long as the jobs
are not cleaned-up. The gather process exports them to local files
and combines the result with any existing local files.
Therefore, the intended usage is to gather the results for various clusters
into one directory.
By keeping the cleanup process of Jobs in the cluster optional, multiple
clients can access the results without sharing the CSV files.
Old results can be cleaned-up to speed up the gathering and they are included
in the plotted graphs as long as their CSV files are still in the current folder.


