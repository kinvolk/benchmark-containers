# benchmark-containers
Benchmark container build files for a variety of cloud-native system-level
benchmarks.

All containers listed below also ship version 0.8.0 of
[dstat](https://github.com/dagwieers/dstat). DStat's CSV output in particular
is a nice way of streaming system metrics.

The containers are based on [Alpine](https://alpinelinux.org/).

fio
===
The FIO container ships release 3.15 of the
[Flexible IO tester](https://github.com/axboe/fio).

stress-ng
=========
The container ships release 0.10.07 of
[stress-ng](https://github.com/ColinIanKing/stress-ng).

sysbench
========
The container ships release 1.0.17 of
[sysbench](https://github.com/akopytov/sysbench).
