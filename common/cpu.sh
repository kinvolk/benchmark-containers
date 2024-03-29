# Please note that we consciously do not define a hashbang interpreter here
# so the script works on systems that only ship either ash or bash.

# Prints the CPU architecture to stdout.
# (either "arm64" or "amd64")
function get_arch() {
    local a=$(lscpu | awk '/^Architecture:/ {print $2}')
    case $a in
        aarch64) a="arm64";;
        x86_64)  a="amd64";;
    esac
    echo $a
}

# Prints the number of (hyperthreaded or physical) CPUs currently online to
# stdout.
function _get_online() {
    # format is e.g.:  1-3,9,15,20-27
    lscpu | sed -n 's/^On-line CPU(s) list:[[:space:]]*//p'
}

function _calc_sums() {
    # calculate intermediate sums, e.g. "1-3,9,15,20-27" => "3 1 1 8"
    local r=""
    for r in $(_get_online | sed 's/,/ /g'); do
        echo "$r" | sed 's/-/ /' | \
            { read a b
              if [ -n "$b" ] ; then
                 # it's a range, e.g. 1-3
                 echo "$((b+1 - a))"
              else
                 # a single cpu (so its "sum" is 1)
                 echo "1"
              fi; }
     done
}

function get_num_cpus() {
    local sums=$(_calc_sums)
    # replace spaces with "+" ("3 1 1 8" => "3+1+1+8"), calculate final sum
    echo $(( $(echo $sums | sed 's/ /+/g') ))
}

# Prints hyperthreading status ("on" or "off") to stdout
function get_ht() {
    lscpu | awk \
      '/^Thread\(s\) per core:/ {if ($4 > 1) print "on"; else print "off"; }'
}

# Prints number of physical cores
function get_num_cores() {
    get_ht | grep -q "off" && { get_num_cpus; return; }
    lscpu -p \
            | sed -n 's/^[0-9]\+,\([0-9]\+,[0-9]\+\),.*/\1/p' \
            | sort | uniq | wc -l
}

# Prints number of sockets
function get_num_sockets() {
    lscpu | awk '/^Socket\(s\):/ {print $2 }'
}

# Prints CPU manufacturer / Model name & revision
function get_model() {
    lscpu | awk '/^Vendor ID:/  { $1=""; $2="";
                                    gsub(/^ +/,"" );
                                    gsub(/ +$/,"");
                                    s=$0 }
                 /^Model name:/ { $1=""; $2="";
                                    gsub(/^ +/,"");
                                    gsub(/ +$/,"");
                                    s=s " " $0 }
                     END { if (s == "APM X-Gene") s="Ampere eMAG";
                                    print s }'
}

function get_system() {
    CPU=$(get_model)
    SOCKETS=$(get_num_sockets)
    CPUS=$(get_num_cpus)
    CORES=$(get_num_cores)
    HT=$(get_ht)
    echo "$CPU (Sockets: $SOCKETS. CPUs: $CPUS. Cores: $CORES. HT: $HT)"
}

case $1 in
   arch) get_arch;;
   cpus) get_num_cpus;;
   ht) get_ht;;
   cores) get_num_cores;;
   sockets) get_num_sockets;;
   model) get_model;;
   system) get_system;;
   *) echo "Unknown argument '$1'" >&2;;
esac
