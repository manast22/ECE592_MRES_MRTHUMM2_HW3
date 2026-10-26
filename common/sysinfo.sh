#!/bin/bash
# Record this machine's CPU/OS/SGX details once, in machines/<host>.txt.
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
out="$REPO_DIR/machines/$(hostname -s).txt"
[ -f "$out" ] && exit 0
mkdir -p "$(dirname "$out")"
{
    echo "== date";   date -Is
    echo "== uname";  uname -a
    echo "== lscpu";  lscpu
    echo "== cpuinfo (cpu 0)"; awk '/^$/{exit} {print}' /proc/cpuinfo
    echo "== sgx devices"; ls -l /dev/sgx* 2>&1
    echo "== sgx dmesg"; dmesg 2>/dev/null | grep -i sgx || echo "(dmesg unavailable)"
    echo "== perf_event_paranoid"; cat /proc/sys/kernel/perf_event_paranoid
    echo "== gramine"; gramine-sgx --version 2>&1 || echo "(none)"
    echo "== gcc"; gcc --version | head -1
    echo "== groups"; id -nG
} > "$out" 2>&1
echo "recorded machine info in $out" >&2
