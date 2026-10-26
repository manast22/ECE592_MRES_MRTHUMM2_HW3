#include "bench.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CALIB_ITERS 20000ULL   /* x1000 adds = 2e7 cycles per sample */
#define CALIB_SAMPLES 11

static int cmp_d(const void *a, const void *b)
{
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

double median_d(double *v, size_t n)
{
    qsort(v, n, sizeof(double), cmp_d);
    return (n & 1) ? v[n / 2] : 0.5 * (v[n / 2 - 1] + v[n / 2]);
}

static double ticks_of(calib_timer_fn timer, int kind, uint64_t iters)
{
    if (timer)
        return (double)timer(kind, iters);
    uint64_t t0 = tsc_start();
    (kind == CALIB_IMUL ? calib_imul_chain : calib_add_chain)(iters);
    uint64_t t1 = tsc_stop();
    return (double)(t1 - t0);
}

static double measure_cpt(calib_timer_fn timer)
{
    double s[CALIB_SAMPLES];
    for (int i = 0; i < CALIB_SAMPLES; i++)
        s[i] = (CALIB_ITERS * 1000.0) / ticks_of(timer, CALIB_ADD, CALIB_ITERS);
    return median_d(s, CALIB_SAMPLES);
}

calib_t bench_calibrate(const char *tag, calib_timer_fn timer)
{
    calib_t c;

    /* ~0.5-1 s of busy work so DVFS settles before we calibrate. */
    for (int i = 0; i < 40; i++)
        ticks_of(timer, CALIB_ADD, CALIB_ITERS);

    c.cyc_per_tick = measure_cpt(timer);

    double s[CALIB_SAMPLES];
    for (int i = 0; i < CALIB_SAMPLES; i++)
        s[i] = ticks_of(timer, CALIB_IMUL, CALIB_ITERS) * c.cyc_per_tick / (CALIB_ITERS * 1000.0);
    c.imul_latency = median_d(s, CALIB_SAMPLES);

    printf("# bench %s\n", tag);
    printf("# calib cyc_per_tick=%.5f imul_latency_cyc=%.3f\n", c.cyc_per_tick, c.imul_latency);
    if (c.imul_latency < 2.7 || c.imul_latency > 3.3)
        fprintf(stderr, "warning: imul latency %.2f != ~3; calibration suspect\n", c.imul_latency);
    fflush(stdout);
    return c;
}

void bench_recheck(const calib_t *c, calib_timer_fn timer)
{
    double now = measure_cpt(timer);
    double drift = (now - c->cyc_per_tick) / c->cyc_per_tick;
    printf("# recheck cyc_per_tick=%.5f drift=%.4f\n", now, drift);
    if (drift > 0.02 || drift < -0.02)
        fprintf(stderr, "warning: clock drifted %.1f%% during run\n", drift * 100);
}
