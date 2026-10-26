/* Shared timing harness for all HW3 experiments.
 *
 * Timing is TSC-based (no PMU). rdtsc ticks at a fixed frequency, so every
 * binary first calibrates TSC ticks -> core cycles with a dependent chain of
 * 1-cycle register adds (see calib.S).
 *
 * Everything above the "host only" line is also compiled into SGX enclaves,
 * so it must stay free of libc I/O. */
#ifndef BENCH_H
#define BENCH_H

#include <stdint.h>
#include <stddef.h>

/* Serialized TSC reads: lfence keeps earlier/later work from leaking across. */
static inline uint64_t tsc_start(void)
{
    uint32_t lo, hi;
    __asm__ volatile("lfence\n\trdtsc\n\tlfence" : "=a"(lo), "=d"(hi) :: "memory");
    return ((uint64_t)hi << 32) | lo;
}

static inline uint64_t tsc_stop(void)
{
    uint32_t lo, hi;
    __asm__ volatile("rdtscp\n\tlfence" : "=a"(lo), "=d"(hi) :: "rcx", "memory");
    return ((uint64_t)hi << 32) | lo;
}

static inline uint64_t xorshift64(uint64_t *s)
{
    uint64_t x = *s;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return *s = x;
}

/* calib.S */
void calib_add_chain(uint64_t iters);   /* 1000 dependent `add reg,reg` per iter */
void calib_imul_chain(uint64_t iters);  /* 1000 dependent `imul reg,reg` per iter */

enum { CALIB_ADD = 0, CALIB_IMUL = 1 };

/* ---- host only ---------------------------------------------------------- */

/* Runs a calibration chain and returns the TSC ticks it took. NULL means
 * "run it right here"; the SGX backend passes a function that does it inside
 * the enclave, so calibration happens where the kernels run. */
typedef uint64_t (*calib_timer_fn)(int kind, uint64_t iters);

typedef struct {
    double cyc_per_tick;   /* core cycles per TSC tick (median) */
    double imul_latency;   /* sanity check: should come out ~3 cycles */
} calib_t;

/* Spins to let the core reach a steady clock, then calibrates.
 * Prints "# calib ..." comment lines to stdout. */
calib_t bench_calibrate(const char *tag, calib_timer_fn timer);

/* Re-run the add-chain calibration and warn on stderr if the ratio drifted. */
void bench_recheck(const calib_t *c, calib_timer_fn timer);

double median_d(double *v, size_t n);

#endif
