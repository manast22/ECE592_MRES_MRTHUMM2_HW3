# Sourced by each experiment's bench/run.sh.
#
#   run_bench MODE CPU OUTFILE BINARY [ARGS...]
#
# MODE: native  - plain process pinned with taskset
#       sgx     - same driver; the timed kernels and their data run inside an
#                 Intel SGX SDK enclave (BINARY_sgx + BINARY_sgx.enclave.so)
# Output: OUTFILE gets "# ..." metadata lines followed by the benchmark's CSV.

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$COMMON_DIR")"

# Print the SMT sibling of $1 and how busy it was over 0.5 s.
sibling_check() {
    local cpu=$1 sib a b
    sib=$(tr ',-' '\n\n' < "/sys/devices/system/cpu/cpu$cpu/topology/thread_siblings_list" | grep -vx "$cpu" | head -1)
    [ -z "$sib" ] && return
    a=($(grep "^cpu$sib " /proc/stat)); sleep 0.5; b=($(grep "^cpu$sib " /proc/stat))
    local idle=$(( (b[4]+b[5]) - (a[4]+a[5]) )) tot=0 i
    for i in 1 2 3 4 5 6 7 8; do tot=$(( tot + b[i] - a[i] )); done
    local busy=0
    [ "$tot" -gt 0 ] && busy=$(( 100 * (tot - idle) / tot ))
    echo "cpu $cpu: SMT sibling cpu $sib was ${busy}% busy" >&2
    [ "$busy" -gt 10 ] && echo "warning: sibling is busy; pick another CPU with the 2nd run.sh argument" >&2
    SIBLING_BUSY=$busy
}

sgx_check() {
    if [ ! -e /dev/sgx_enclave ]; then
        echo "error: /dev/sgx_enclave not found: SGX is not enabled on $(hostname -s)" >&2
        return 1
    fi
    if [ ! -r /dev/sgx_enclave ] || [ ! -w /dev/sgx_enclave ]; then
        echo "error: no access to /dev/sgx_enclave. Your session must be in the 'sgx' group" >&2
        echo "       (check: id -nG). Log in again after being added, or run: sg sgx -c \"$0 $*\"" >&2
        return 1
    fi
}

run_bench() {
    local mode=$1 cpu=$2 out=$3 bin=$4
    shift 4
    mkdir -p "$(dirname "$out")"
    "$COMMON_DIR/sysinfo.sh"

    local cmd
    case $mode in
        native) make -s && cmd=(taskset -c "$cpu" "./$bin" "$@") ;;
        sgx)    sgx_check && make -s sgx && cmd=(taskset -c "$cpu" "./${bin}_sgx" "$@") ;;
        *) echo "unknown mode '$mode' (native|sgx)" >&2; return 1 ;;
    esac || return 1

    SIBLING_BUSY=?
    sibling_check "$cpu"
    echo ">> ${cmd[*]}  >  $out" >&2
    {
        echo "# host $(hostname -s) mode $mode cpu $cpu sibling_busy_pct $SIBLING_BUSY date $(date -Is)"
        echo "# cmd ${cmd[*]}"
        "${cmd[@]}"
    } > "$out"
}
