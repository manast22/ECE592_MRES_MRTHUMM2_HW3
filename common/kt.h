/* Kernel-side interface ("kt"): the part of an experiment that is timed.
 *
 * Each experiment implements these four functions in one file (e.g.
 * q01_pipelined/bench/q1_kt.c). The same file is compiled into the native
 * benchmark and into the SGX enclave, so it may only use what the enclave's
 * trusted libc offers (string.h, stdlib.h malloc/free; no stdio, no mmap
 * unless guarded by #ifndef IN_ENCLAVE).
 *
 * The host driver never calls these directly; it goes through kbackend.h. */
#ifndef KT_H
#define KT_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>

/* Number of runnable entries (kernels, or loaded data slots). */
uint64_t kt_count(void);

/* Describe entry i: a short name plus two experiment-defined numbers. */
void kt_entry(uint64_t i, char *name, size_t cap, uint64_t *a, uint64_t *b);

/* Experiment-defined setup (build chains, load a pattern, ...). 0 = ok. */
int kt_setup(const void *data, size_t len, uint64_t p0, uint64_t p1, uint64_t p2);

/* Run entry i for `iters` and return the TSC ticks measured around it. */
uint64_t kt_run(uint64_t i, uint64_t iters);

static inline void kt_copy_name(char *dst, size_t cap, const char *src)
{
    if (!cap)
        return;
    strncpy(dst, src, cap - 1);
    dst[cap - 1] = '\0';
}

#endif
