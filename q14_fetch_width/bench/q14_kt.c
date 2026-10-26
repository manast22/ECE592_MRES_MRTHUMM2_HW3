/* Q14 timed part (native + enclave): the generated NOP blocks in kernels.S.
 * kt_entry reports a = NOP length in bytes, b = NOPs per block. */
#include "bench.h"
#include "kt.h"

struct nop_entry {
    void (*fn)(uint64_t iters);
    uint64_t len;
    uint64_t count;
};
extern const struct nop_entry nop_table[];
extern const uint64_t nop_table_len;

uint64_t kt_count(void)
{
    return nop_table_len;
}

void kt_entry(uint64_t i, char *name, size_t cap, uint64_t *a, uint64_t *b)
{
    kt_copy_name(name, cap, "nop");
    *a = i < nop_table_len ? nop_table[i].len : 0;
    *b = i < nop_table_len ? nop_table[i].count : 0;
}

int kt_setup(const void *data, size_t len, uint64_t p0, uint64_t p1, uint64_t p2)
{
    (void)data, (void)len, (void)p0, (void)p1, (void)p2;
    return 0;
}

uint64_t kt_run(uint64_t i, uint64_t iters)
{
    if (i >= nop_table_len)
        return 0;
    uint64_t t0 = tsc_start();
    nop_table[i].fn(iters);
    return tsc_stop() - t0;
}
