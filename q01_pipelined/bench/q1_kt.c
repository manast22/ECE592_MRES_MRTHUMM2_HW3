/* Q1 timed part (native + enclave): the four chain kernels in kernels.S. */
#include "bench.h"
#include "kt.h"

void add_dep(uint64_t), add_indep(uint64_t), imul_dep(uint64_t), imul_indep(uint64_t);

static const struct {
    const char *name;
    void (*fn)(uint64_t);
} variants[] = {
    {"add_dep", add_dep},
    {"add_indep", add_indep},
    {"imul_dep", imul_dep},
    {"imul_indep", imul_indep},
};
#define NV (sizeof(variants) / sizeof(variants[0]))

uint64_t kt_count(void)
{
    return NV;
}

void kt_entry(uint64_t i, char *name, size_t cap, uint64_t *a, uint64_t *b)
{
    kt_copy_name(name, cap, i < NV ? variants[i].name : "?");
    *a = *b = 0;
}

int kt_setup(const void *data, size_t len, uint64_t p0, uint64_t p1, uint64_t p2)
{
    (void)data, (void)len, (void)p0, (void)p1, (void)p2;
    return 0;
}

uint64_t kt_run(uint64_t i, uint64_t iters)
{
    if (i >= NV)
        return 0;
    uint64_t t0 = tsc_start();
    variants[i].fn(iters);
    return tsc_stop() - t0;
}
