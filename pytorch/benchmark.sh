#!/bin/bash

cd $(dirname $0)

# Optional parameters
pgw="http://pushgateway.monitoring:9091"
do_post="true"
debug_stdout="false"
test_filters=""
force_cpus=""

# command line parameters for the benchmark job
usage() {
    echo "Usage:"
    echo "  docker run -ti pytorch <cloud> <instance/shape> [options]"
    echo "  <cloud>          - free-form string to use for pushgateway reports"
    echo "  <instance/shape> - free-form string to use for pushgateway reports"
    echo "Options:"
    echo " -d                - dump pushgateway input to stdout too"
    echo " -p <push-gateway> - URL of prometheus push gateway. Default: $pgw"
    echo " -n                - Do not post to pushgateway. Useful with -d."
    echo " -k                - Only run specific tests; see https://github.com/pytorch/benchmark#examples-of-benchmark-filters."
    echo " -c <num cpus>     - Force a number of CPUs to use (must not be higher than CPUs available)."
    echo "                     By default the benchmark will use all CPUs available."
    echo
}
# --


[ $# -lt 2 ] && {
    usage
    exit 1
}

[ "help" = "$1" -o "-h" = "$1" -o "--help" = "$1" ] && {
    usage
    exit 0
}

# required parameters
cloud=""
instance=""

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        -d) debug_stdout="true"; shift;;
        -n) do_post="false"; shift;;
        -p) shift; pgw="$1"; shift;;
        -k) shift; test_filters="-k $1"; shift;;
        -c) shift; force_cpus="$1"; shift;;
        *) [ -z "$cloud" ] && { cloud="$1"; shift; continue; }
           [ -z "$instance" ] && { instance="$1"; shift; continue; }

           echo "UNKNOWN Parameter / argument starting at '$@'"
           usage
           exit 1;;
    esac
done


# auto-configured values
jobname="pytorch"
ts=$(date --rfc-3339 seconds | sed -e 's/ /__/' -e 's/+.*//')

echo "#### Running pytorch benchmark '$ts' on cloud '$cloud' shape '$instance' w/ filters:'$test_filters'"

function push_to_gw() {
    local body=$(mktemp)
    local curl="curl -s --data-binary @$body $pgw/metrics/job/$jobname/cloud/$cloud/instance/$instance/run/$ts"

    cat - >"$body"

    [ "$debug_stdout" = "true" ] && {
        echo "$curl"
        cat "$body"
    }

    [ "$do_post" = "true" ] && {
        $curl
    }

    rm "$body"
}
# --

function list_benchmarks() {
    echo "# TYPE pytorch_benchmark_status counter"
    ./run.sh --color=no --cpu_only --benchmark-warmup=on --ignore_machine_config \
             --benchmark-only --collect-only $test_filters 2>/dev/null \
    | awk '
         /<Function test_/ {
             phase = gensub(/.*Function test_(.*)\[.*/,"\\1",1)
             test = gensub(/.*\[(.*)\].*/,"\\1",1)
             tshort = gensub(/^(.{10}).+(.{10})/,"\\1...\\2",1,test)
             if (prev_test != test)
                 print "pytorch_benchmark_status{tshort=\"" tshort "\",test=\"" test "\"} 0"
             prev_test = test }'
}
# --

function init_results() {
    local cpus="$1"
    local tset="$2"
    local statfile="$3"

    echo "# TYPE pytorch_benchmark_cpus counter"
    echo "pytorch_benchmark_cpus{taskset=\"$tset\"} $cpus"
    echo "# TYPE pytorch_benchmark_result gauge"
    awk '/^pytorch_benchmark_status/ {
             test = gensub(/.*test="(.*)".*/,"\\1",1)
             split("min max mean stddev median iqr outliers1 outliers2 ops rounds iterations", metrics)
             tshort = gensub(/^(.{10}).+(.{10})/,"\\1...\\2",1,test)
             for (m in metrics) {
                 print "pytorch_benchmark_result{tshort=\"" tshort "\",test=\"" test "\",phase=\"train\",metric=\"" metrics[m] "\"} 0"
                 print "pytorch_benchmark_result{tshort=\"" tshort "\",test=\"" test "\",phase=\"eval\",metric=\"" metrics[m] "\"} 0"
             }
         }' "$statfile"
}
# --

function get_taskset() {
    local req_num_cpus="$1"
    local resfile="$2"

    # calculate number of CPUs from active CPUs, fall back to core count if unavailable
    local -a avail_cpus=$(lscpu | sed -n 's/On-line CPU(s) list:[[:space:]]*\([0-9]\+\)-\([0-9]\+\).*/(\1 \2)/p')
    local core_count=$(grep -cE '^processor[[:space:]]*:' /proc/cpuinfo)
    local num_avail_cpus=$(( ${avail_cpus[1]:-$core_count} - ${avail_cpus[0]:-"0"} + 1))


    # determine result number of CPUs, limit to available CPUs
    local result_num_cpus="${req_num_cpus:-"999999999"}"
    [ "$num_avail_cpus" -lt "$result_num_cpus" ] && result_num_cpus="$num_avail_cpus"

    # calculate cpuset from above
    local lower_cpu="${avail_cpus[0]:-"0"}"
    local upper_cpu=$((${avail_cpus[0]:-"0"} + $result_num_cpus - 1))
    local tset="$lower_cpu-$upper_cpu"

    echo "#### CPUs: requested '$req_num_cpus' available '$num_avail_cpus' ('${avail_cpus[0]}'-'${avail_cpus[1]}', cores '$core_count') = '$result_num_cpus' ('$tset')"
    echo "$result_num_cpus $tset" >"$resfile"
}
# --

function run_benchmark() {
    local taskset="$1"
    local statfile="$2"
    local resfile="$3"
    local done="false"

    taskset --cpu-list "$tset" ./run.sh --color=no --cpu_only --benchmark-warmup=on --ignore_machine_config \
             --benchmark-only $test_filters 2>/dev/null \
        | unbuffer -p tee "$resfile" \
        | unbuffer -p sed -n 's/.*test_\(train\|eval\)\[\([^]]\+\)\]/\1 \2/p' \
        | while read phase test status rest; do

            # tests done?
            $done && continue
            grep '\---------------------------------------------------' "$resfile" && {
                echo "#### Benchmark tests concluded"
                done="true"
                continue
            }

            local val
            case "$phase" in
                train)
                    val=11 # train failed
                    echo "$status" | grep -q "PASSED" && val=1
                    ;;
                eval)
                    val=12 # eval failed
                    echo "$status" | grep -q "PASSED" && val=2
                    ;;
                *)  val=13 # unknown error
            esac
            echo "#### Test $test phase $phase $status ($val)"
            sed -i "s/,test=\"$test\"}.*/,test=\"$test\"} $val/" "$statfile"
            cat "$statfile" | push_to_gw
          done
}
# --

function get_results() {
    local resfile="$1"
    local results="$(mktemp)"

    # get summary data for easier parsing, remove annotation (in "(...)") and "," from values
    grep -A 99999 '\--------------' "$resfile" | sed -e 's/([^)]\+)//g' -e 's/,//g' >"$results"

    cat "$results" >&2

    echo "# TYPE pytorch_benchmark_result gauge"
    awk '/^test_/ {
        phase = gensub(/test_(.*)\[.*/,"\\1",1)
        test  = gensub(/.*\[(.*)\].*/,"\\1",1)
        tshort = gensub(/^(.{10}).+(.{10})/,"\\1...\\2",1,test)
        metrics["min"] = $2
        metrics["max"] = $3
        metrics["mean"] = $4
        metrics["stddev"] = $5
        metrics["median"] = $6
        metrics["iqr"] = $7
        split($8,o,";")
        metrics["outliers1"] = o[1]
        metrics["outliers2"] = o[2]
        metrics["ops"] = $9
        metrics["rounds"] = $10
        metrics["tierations"] = $11
        for (mk in metrics) {
            print "pytorch_benchmark_result{tshort=\"" tshort "\",test=\"" test "\",phase=\"" phase "\",metric=\"" mk "\"} " metrics[mk] 
        }
    }' "$results"

    rm "$results"
}
# --

cpufile=$(mktemp)
statusfile=$(mktemp)
resfile=$(mktemp)


get_taskset "$force_cpus" "$cpufile"
read cpus tset <"$cpufile"

list_benchmarks | tee "$statusfile" | push_to_gw
init_results "$cpus" "$tset" "$statusfile" | push_to_gw

run_benchmark "$tset" "$statusfile" "$resfile"
get_results "$resfile" | push_to_gw

rm "${statusfile}" "${resfile}" "${cpufile}"
