# benchmark-containers
Benchmark container build files for a variety of cloud-native system-level
benchmarks.

fio
===
The FIO container ships release 3.15 of the
[Flexible IO tester](https://github.com/axboe/fio), and also contains version
0.8.0 of [dstat](https://github.com/dagwieers/dstat).
The container is based on Alpine, to optimize for image size.

stress-ng
=========
The container ships release 0.10.07 of
[stress-ng](https://github.com/ColinIanKing/stress-ng), and also contains
version 0.8.0 of [dstat](https://github.com/dagwieers/dstat).
The container is based on Alpine, to optimize for image size.
