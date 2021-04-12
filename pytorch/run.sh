#!/bin/bash

set -xeuo pipefail

source /root/venv/bin/activate

cd /root/benchmark
exec unbuffer pytest test_bench.py $@
