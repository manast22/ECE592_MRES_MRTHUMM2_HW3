/* Host side of the SGX timer probe.
 * 1. Does rdtsc work inside the enclave at all?
 * 2. What is its resolution there (back-to-back deltas)?
 * 3. Do inside-enclave timing, host-side ECALL timing and native timing agree
 *    on the same 2e7-cycle dependent add chain?
 * 4. How much does an empty ECALL cost? */
#include <stdio.h>
#include <stdlib.h>

#include "bench.h"
#include "probe_u.h"
#include "sgx_urts.h"

#define TRIALS 11
#define ITERS 20000ULL   /* x1000 adds */

static void check(sgx_status_t s, const char *what)
{
    if (s != SGX_SUCCESS) {
        printf("%s: FAILED, sgx_status 0x%x%s\n", what, s,
               s == SGX_ERROR_ENCLAVE_CRASHED ? " (enclave crashed: instruction faulted)" : "");
        exit(1);
    }
}

int main(int argc, char **argv)
{
    const char *path = argc > 1 ? argv[1] : "enclave.signed.so";
    sgx_enclave_id_t eid;
    check(sgx_create_enclave(path, 1 /* debug */, NULL, NULL, &eid, NULL), "sgx_create_enclave");
    printf("enclave created (debug mode)\n");

    calib_t c = bench_calibrate("sgx_timer_probe", NULL);

    /* 1. rdtsc inside the enclave */
    uint64_t in, before = tsc_start();
    check(ecall_rdtsc(eid, &in), "rdtsc inside enclave");
    uint64_t after = tsc_start();
    printf("rdtsc in enclave: OK, value within host bracket: %s (%llu ticks after host read)\n",
           in > before && in < after ? "yes" : "NO", (unsigned long long)(in - before));

    /* 2. resolution */
    enum { N = 64 };
    uint64_t d[N];
    check(ecall_rdtsc_deltas(eid, d, N), "rdtsc deltas");
    double dd[N];
    uint64_t mn = ~0ULL;
    for (int i = 0; i < N; i++) {
        dd[i] = d[i];
        if (d[i] < mn)
            mn = d[i];
    }
    printf("back-to-back rdtsc delta in enclave: min %llu, median %.0f ticks\n",
           (unsigned long long)mn, median_d(dd, N));

    /* 3. same work timed three ways */
    double inside[TRIALS], outside[TRIALS], native[TRIALS], nop[TRIALS];
    for (int t = 0; t < TRIALS; t++) {
        uint64_t ticks;
        check(ecall_timed_add_chain(eid, ITERS, &ticks), "timed add chain");
        inside[t] = ITERS * 1000.0 / ticks;

        uint64_t t0 = tsc_start();
        check(ecall_add_chain(eid, ITERS), "add chain");
        outside[t] = ITERS * 1000.0 / (tsc_stop() - t0);

        t0 = tsc_start();
        calib_add_chain(ITERS);
        native[t] = ITERS * 1000.0 / (tsc_stop() - t0);
    }
    printf("cycles per TSC tick (median of %d), 2e7-add chain:\n", TRIALS);
    printf("  native (host rdtsc)            %.5f\n", median_d(native, TRIALS));
    printf("  enclave, rdtsc inside enclave  %.5f\n", median_d(inside, TRIALS));
    printf("  enclave, host times the ECALL  %.5f\n", median_d(outside, TRIALS));

    /* 4. ECALL overhead */
    for (int t = 0; t < TRIALS; t++) {
        uint64_t t0 = tsc_start();
        for (int i = 0; i < 1000; i++)
            ecall_nop(eid);
        nop[t] = (tsc_stop() - t0) / 1000.0;
    }
    double ov = median_d(nop, TRIALS);
    printf("empty ECALL round trip: %.0f ticks = %.0f cycles\n", ov, ov * c.cyc_per_tick);

    sgx_destroy_enclave(eid);
    return 0;
}
