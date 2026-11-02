# Sourced by the pmu.sh scripts. PMU counters are used only to VERIFY the
# TSC-based results (see top-level README, "PMU policy"); native mode only,
# since counters are not visible inside SGX enclaves.
#
#   pmu_count CPU EVENTS CMD...   -> prints "ev1=count ev2=count ..." (user-space counts)
#
# Callers use a difference method: run the same command twice with more or
# less timed work and subtract, so calibration, setup and warm-up cancel out.

pmu_count() {
    local cpu=$1 events=$2
    shift 2
    perf stat -x, -e "$events" -o /dev/stderr taskset -c "$cpu" "$@" 2>&1 >/dev/null \
        | awk -F, '$1 ~ /^[0-9]+$/ { split($3, e, ":"); printf "%s=%s ", e[1], $1 } END { print "" }'
}
