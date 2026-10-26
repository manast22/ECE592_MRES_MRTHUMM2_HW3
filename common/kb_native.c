/* Native backend: the kt_* functions are linked into this process. */
#include <stdio.h>

#include "kbackend.h"
#include "kt.h"

calib_timer_fn kb_calib_timer = NULL;

void kb_init(void)
{
    printf("# backend native\n");
}

void kb_fini(void)
{
}

uint64_t kb_count(void)
{
    return kt_count();
}

void kb_entry(uint64_t i, char *name, size_t cap, uint64_t *a, uint64_t *b)
{
    kt_entry(i, name, cap, a, b);
}

int kb_setup(const void *data, size_t len, uint64_t p0, uint64_t p1, uint64_t p2)
{
    return kt_setup(data, len, p0, p1, p2);
}

uint64_t kb_run(uint64_t i, uint64_t iters)
{
    return kt_run(i, iters);
}
