/* Q3 / Q15 timed part (native + enclave).
 * kt_setup(pattern, len, slot) keeps a private copy of a pattern array (in the
 * SGX build that copy lives in enclave memory); kt_run(slot, passes) times
 * branch_kernel over it. */
#include <stdlib.h>

#include "bench.h"
#include "kt.h"

uint64_t branch_kernel(const uint8_t *pat, uint64_t len, uint64_t passes);

#define MAX_SLOTS 64
static uint8_t *pat[MAX_SLOTS];
static size_t pat_len[MAX_SLOTS];
static uint64_t nslots;

uint64_t kt_count(void)
{
    return nslots;
}

void kt_entry(uint64_t i, char *name, size_t cap, uint64_t *a, uint64_t *b)
{
    kt_copy_name(name, cap, "pattern");
    *a = i < nslots ? pat_len[i] : 0;
    *b = 0;
}

int kt_setup(const void *data, size_t len, uint64_t slot, uint64_t p1, uint64_t p2)
{
    (void)p1, (void)p2;
    if (slot >= MAX_SLOTS || !data || !len)
        return -1;
    free(pat[slot]);
    if (!(pat[slot] = malloc(len)))
        return -1;
    memcpy(pat[slot], data, len);
    pat_len[slot] = len;
    if (slot >= nslots)
        nslots = slot + 1;
    return 0;
}

uint64_t kt_run(uint64_t slot, uint64_t passes)
{
    if (slot >= nslots || !pat[slot])
        return 0;
    uint64_t t0 = tsc_start();
    branch_kernel(pat[slot], pat_len[slot], passes);
    return tsc_stop() - t0;
}
