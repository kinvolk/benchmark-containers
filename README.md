# benchmark-containers

**Repository Structure:**
This repository contains a benchmark suite for nodes in Kubernetes clusters.
Corner stones are the benchmark containers which include the tooling
that the Kubernetes deployments need to conduct the automated benchmarking.
The `cluster-script` deploys the Kubernetes apps to configured clusters.
Since multiple clusters can be benchmarked the script runs on a local machine
or an external server and is not deployed on one of the benchmarked clusters.

# Benchmark container build files
The top level build script and the container subfolders as explained below form
the benchmark container build files for a variety of cloud-native system-level
benchmarks. All containers are published as images for arm64 and amd64 on
[quay.io/kinvolk/CONTAINERNAME](https://quay.io/organization/kinvolk).

All containers listed below also ship version 0.8.0 of
[dstat](https://github.com/dagwieers/dstat). DStat's CSV output in particular
is a nice way of streaming system metrics.

The containers are based on [Alpine](https://alpinelinux.org/) and thus use
musl as libc instead of glibc.

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

memtier / memcached / redis container
=====================================
The memtier container ships release 1.2.17 of Redis'
[memtier](https://github.com/RedisLabs/memtier_benchmark/) benchmark. The
container is fully self-sufficient and also ships release 1.5.19 of
[memcached](https://github.com/memcached/memcached/) as well as release 5.0.6
of [redis](https://github.com/antirez/redis/).
Before running the benchmark, start redis and memcached:

	* memcached -u benchmark -t 32
	* su benchmark -c 'redis-server --port 7777'

Then run the benchmark, e.g.

    * memtier_benchmark -s 127.0.0.1 -p 11211 -P memcache_binary -t 32 -n 10000 –ratio 1:1 -c 25 -x 10 -d 100 –key-pattern S:S

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

nginx container
===============
The container ships the [NGINX](https://en.wikipedia.org/wiki/Nginx) web server
in a configuration that serves 404 responses on port 8000. It works both as a
root container or as user with the ID 1000.

ab container
============
The container ships [ApacheBench](https://en.wikipedia.org/wiki/ApacheBench) from
apache2-utils which measures the maximal requests/s that a web server can answer.

fortio container
================
The container ships [fortio](https://github.com/fortio/fortio), a load testing
tool that can measure latencies for a fixed number of requests/s both for HTTP
and gRPC. It also works as server.

wrk2-benchmark container
========================
The container ships a build of [wrk2](https://github.com/giltene/wrk2), a modification
of wrk that reports correct tail latencies for HTTP requests by taking Coordinated
Omission into account.

The `/usr/local/share/wrk2/body-100-report.lua` Lua script can be used to enhance the
log with additional information and set the request body length to 100 bytes.

The container is named _wrk2-benchmark_ to avoid a conflict with the
[other wrk2](https://quay.io/repository/kinvolk/wrk2) container build in quay.io.

# Kubernetes cluster benchmark script
The `cluster-script` folder contains scripts to run the benchmark containers
on Kubernetes clusters and compare the results.

The `run-for-list.sh` script runs the benchmark for all clusters provided in
a configuration file. The configuration contains the `kubeconfig` path,
CPU architecture of the benchmarked node, the costs per hour, metadata (e.g.,
the cloud region), the number of benchmark iterations, and finally the name of
the benchmarked node, and the name of a fixed x86 node.
The fixed x86 node is used as network client and should be the same hardware type
across all tested clusters to get comparable results from the point of an external
network client.

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

*Note:* It would be possible to deploy the benchmark script itself to the cluster
if you use one large hybrid cluster that contains all the nodes you want to benchmark.
Yet, the script does not assume this right now and will need some minor tweaks
for that to work (to controll the parallelism), and a nice web UI to start the
benchmark and show the results.


## Example Usage

We provision three [Lokomotive Kubernetes](https://github.com/kinvolk/lokomotive-kubernetes/) clusters
on Packet. The `intel` cluster gets a worker pool `pool` with an Intel XEON node,
the `amd` cluster gets a worker pool `pool` with an AMD EPYC worker node,
and the `ampere` cluster gets a worker pool `pool` with an Ampere eMAG worker node.
In addition, all three clusters get another worker pool `x86client` with an Intel XEON worker node as unified
network client.
First change to the subdirectory `cluster-terraform` which has all three clusters preconfigured.
Create a `terraform.tfvar` file and enter your Packet project ID, your SSH public keys,
your domain zone managed by AWS Route53 and its ID:

```
project_id = "abcdef-abcdef-abcdef"
ssh_keys = ["ssh-rsa AAAAB…abcdefg mail@mail.mail"]
dns_zone = "mydelegatedawssubdomain.mydomain.net"
dns_zone_id = "Z1234ABCDEFG"
```

Set the environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`,
and `PACKET_AUTH_TOKEN` for Terraform.
With Terraform 11, run `terraform init` followed by `terraform apply` to create the clusters.

After provisioning the clusters and noting the worker node names
we save this information to a file `list` as in the following lines.
The format is `KUBECONFIG,ARCH,COST,META,ITERATIONS,BENCHMARKNODE,FIXEDX86NODE`.
`META` here refers to the Packet region, and `COSTS` is 1$/hour for Ampere eMAG and AMD EPYC
but 2$/hour for Intel XEON benchmark worker nodes.
If the file is not stored in the same folder as the Terraform assets, adjust the paths.
If you used other cluster names or pool names, adjust them as well.

```
./assets-intel/auth/kubeconfig,amd64,2.0,sjc1,10,intel-pool-worker-0,intel-x86client-worker-0
./assets-amd/auth/kubeconfig,amd64,1.0,sjc1,10,amd-pool-worker-0,amd-x86client-worker-0
./assets-ampere/auth/kubeconfig,arm64,1.0,sjc1,10,ampere-pool-worker-0,ampere-x86client-worker-0
```

That `list` file serves as input for the `run-for-list.sh` script that runs the `benchmark.sh` script for each
cluster with the environment variables set up according to the cluster line.

We run the script with the arguments `benchmark` to run a benchmark, and `gather` to store the output
as local CSV files and creates SVG and PNG graphs in the current directory:

```
…/kinvolk/benchmark-containers/cluster-script/run-for-list.sh list benchmark+gather
[… prints which benchmarks are run in parallel for all clusters]
```

After roughly 3 hours all are done. You can look for the status via
`KUBECONFIG=the/path/to/kubeconfig kubectl -n benchmark get pods -o wide` (or `get jobs`).
You can observe the output of a run via `KUBECONFIG=… kubectl -n benchmark logs PODNAME`.

To not run all benchmarks but only certain ones of a category, specify them via environment variables:

```
NETWORK="iperf3 ab" MEMTIER="memcached" STRESSNG=" " /kinvolk/benchmark-containers/cluster-script/run-for-list.sh list benchmark+gather
```

In this example the first variable means that only the `iperf3` and `ab` benchmarks are run (but not `wrk2` and `fortio`) from the `NETWORK` category.
The second variable means that only the `memcached` benchmark is run (but not `redis`) from the `MEMTIER` category.
The third variable means that no benchmark of the `STRESSNG` category is run (available are `spawn hsearch crypt atomic tsearch qsort shm sem lsearch bsearch vecmath matrix memcpy`).
A missing fourth variable `SYSBENCH` could be used to specify which benchmarks are run from that category, but since it's not specified the default `fileio mem cpu` is used.

When a second user run the same command with only the `gather` parameter, the user can download the benchmark results as well.

A final `cleanup` parameter removes all jobs and the whole `benchmark` namespace and leaves no trace on the clusters.
This can be combined in one execution via the `benchmark+gather+cleanup` parameter.
