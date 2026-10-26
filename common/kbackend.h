/* Host-side backend: how a driver reaches the timed kernels.
 *
 *   kb_native.c   calls the kt_* functions directly (normal process)
 *   sgx/kb_sgx.c  creates an SGX enclave and calls them through ECALLs
 *
 * Drivers are written once against this API; the Makefile links one backend
 * into <bench> and the other into <bench>_sgx. */
#ifndef KBACKEND_H
#define KBACKEND_H

#include "bench.h"

/* Prints a "# backend ..." line. Exits with a message on failure. */
void kb_init(void);
void kb_fini(void);

uint64_t kb_count(void);
void kb_entry(uint64_t i, char *name, size_t cap, uint64_t *a, uint64_t *b);
int kb_setup(const void *data, size_t len, uint64_t p0, uint64_t p1, uint64_t p2);
uint64_t kb_run(uint64_t i, uint64_t iters);

/* Pass to bench_calibrate / bench_recheck (NULL for native). */
extern calib_timer_fn kb_calib_timer;

#endif
