lscpu | grep -E "Model name|Thread|Core|Socket|NUMA|MHz|Flags" | cut -c1-300
grep -o -w -E "sgx|sgx_lc|constant_tsc|nonstop_tsc" /proc/cpuinfo | sort -u
ls -l /dev/sgx* 2>/dev/null; dmesg 2>/dev/null | grep -i sgx | head
cat /proc/sys/kernel/perf_event_paranoid
uname -r; gcc --version | head -1; python3 --version
which gramine-sgx gramine-direct 2>/dev/null
sudo -n true 2>/dev/null && echo "have sudo" || echo "no sudo"