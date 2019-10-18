# benchmark-containers
Benchmark container build files for a variety of cloud-native system-level
benchmarks.

All containers listed below also ship version 0.8.0 of
[dstat](https://github.com/dagwieers/dstat). DStat's CSV output in particular
is a nice way of streaming system metrics.

The containers are based on [Alpine](https://alpinelinux.org/).

Building
========
As all containers share dstat, which needs a patch from `common/`, and since
Docker cannot include files from outside its build directory, we provide a
build script for creating container images: `build.sh` in the project root.

Call `./build.sh` without arguments to buils all containers in the project, or
`./build.sh <container> [<container>] ...` to build individual containers
(e.g. `./build.sh fio` to just build the Fio container.

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
