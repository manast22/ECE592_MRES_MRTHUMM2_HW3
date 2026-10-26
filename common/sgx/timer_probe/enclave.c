/* Timer probe enclave: can we use rdtsc inside SGX on this machine? */
#include "bench.h"
#include "probe_t.h"

void ecall_rdtsc(uint64_t *tsc)
{
    *tsc = tsc_start();
}

void ecall_rdtsc_deltas(uint64_t *deltas, size_t n)
{
    uint64_t prev = tsc_start();
    for (size_t i = 0; i < n; i++) {
        uint64_t now = tsc_start();
        deltas[i] = now - prev;
        prev = now;
    }
}

void ecall_timed_add_chain(uint64_t iters, uint64_t *ticks)
{
    uint64_t t0 = tsc_start();
    calib_add_chain(iters);
    uint64_t t1 = tsc_stop();
    *ticks = t1 - t0;
}

void ecall_add_chain(uint64_t iters)
{
    calib_add_chain(iters);
}

void ecall_nop(void)
{
}
