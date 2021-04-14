# PyTorch benchmark container

This container provides the [pytorch](https://github.com/pytorch/benchmark) machine learning framework as well as the [pytorch-benchmark](https://github.com/pytorch/benchmark).

A convenience wrapper script, `benchmark.sh` is supplied for ease of use. The convenience script supports feeding progress and result metrics to a Prometheus [pushgateway](https://github.com/prometheus/pushgateway). A dashboard displaying progress and results is also provided.


![Pytorch Grafana dashboard screenshot](pytorch-grafana.png "Pytorch benchmark Grafana dashboard")

## Building the image
```shell
$ docker build -t pytorch .
```

## Running the image
```shell
$ docker run -ti pytorch -h
Usage:
  docker run -ti pytorch <cloud> <instance/shape> [options]
  <cloud>          - free-form string to use for pushgateway reports
  <instance/shape> - free-form string to use for pushgateway reports
Options:
 -d                - dump pushgateway input to stdout too
 -p <push-gateway> - URL of prometheus push gateway. Default: http://pushgateway.monitoring:9091
 -n                - Do not post to pushgateway. Useful with -d.
 -k                - Only run specific tests; see https://github.com/pytorch/benchmark#examples-of-benchmark-filters.
 -c <num cpus>     - Force a number of CPUs to use (must not be higher than CPUs available).
                     By default the benchmark will use all CPUs available.

$ docker run -ti pytorch my-cloud my-instance-name
#### Running pytorch benchmark '2021-04-14__11:59:35' on cloud 'my-cloud' shape 'my-instance-name' w/ filters:''
#### CPUs: requested '' available '12' ('0'-'11', cores '12') = '12' ('0-11')
#### Test BERT_pytorch-cpu-jit phase train PASSED (1)
#### Test BERT_pytorch-cpu-jit phase eval PASSED (2)
#### Test LearningToPaint-cpu-jit phase eval PASSED (2)
...
```
