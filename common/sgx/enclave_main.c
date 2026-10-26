/* Enclave entry points: thin forwards to the experiment's kt_* functions. */
#include "bench.h"
#include "kb_t.h"
#include "kt.h"

uint64_t ecall_count(void)
{
    return kt_count();
}

void ecall_entry(uint64_t i, char *name, size_t cap, uint64_t *a, uint64_t *b)
{
    kt_entry(i, name, cap, a, b);
}

int ecall_setup(const uint8_t *data, size_t len, uint64_t p0, uint64_t p1, uint64_t p2)
{
    return kt_setup(data, len, p0, p1, p2);
}

uint64_t ecall_run(uint64_t i, uint64_t iters)
{
    return kt_run(i, iters);
}

uint64_t ecall_calib(int kind, uint64_t iters)
{
    uint64_t t0 = tsc_start();
    (kind == CALIB_IMUL ? calib_imul_chain : calib_add_chain)(iters);
    return tsc_stop() - t0;
}
