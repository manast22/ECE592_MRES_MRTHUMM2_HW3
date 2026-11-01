/* Pointer-chase driver shared by Q2 (OoO), Q4 (ROB) and Q5 (PRF).
 * The timed part (chains + kernels) is chase_kt.c, reached via kbackend.h,
 * so the same driver runs natively or with the chase inside an SGX enclave.
 *
 * Output CSV: kind,n,trial,ticks,cycles,iters,cyc_per_iter */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "kbackend.h"

static int selected(const char *kind, const char *filter)
{
    if (!filter)
        return 1;
    size_t len = strlen(kind);
    for (const char *s = filter; *s;) {
        const char *e = strchr(s, ',');
        size_t l = e ? (size_t)(e - s) : strlen(s);
        if (l == len && !strncmp(s, kind, l))
            return 1;
        s += l + (e != NULL);
    }
    return 0;
}

/* "-n lo:hi:step": run only entries whose filler count is lo, lo+step, ... <= hi. */
static int n_selected(uint64_t n, uint64_t lo, uint64_t hi, uint64_t step)
{
    return n >= lo && n <= hi && (n - lo) % step == 0;
}

int main(int argc, char **argv)
{
    int trials = 11, thp = 0;
    size_t mb = 128;
    uint64_t iters = 20000, seed = 0x9e3779b97f4a7c15ULL;
    const char *filter = NULL;
    uint64_t n_lo = 0, n_hi = UINT64_MAX, n_step = 1;
    int opt;
    while ((opt = getopt(argc, argv, "t:i:s:k:n:Hr:")) != -1) {
        switch (opt) {
        case 't': trials = atoi(optarg); break;
        case 'i': iters = strtoull(optarg, NULL, 0); break;
        case 's': mb = strtoull(optarg, NULL, 0); break;
        case 'k': filter = optarg; break;
        case 'n':
            if (sscanf(optarg, "%llu:%llu:%llu", (unsigned long long *)&n_lo,
                       (unsigned long long *)&n_hi, (unsigned long long *)&n_step) != 3 || !n_step) {
                fprintf(stderr, "-n expects lo:hi:step\n");
                return 1;
            }
            break;
        case 'H': thp = 1; break;
        case 'r': seed = strtoull(optarg, NULL, 0); break;
        default:
            fprintf(stderr,
                    "usage: %s [-t trials] [-i iters] [-s MB per chain] [-k kinds] [-n lo:hi:step] [-H] [-r seed]\n"
                    "  -n  only run kernels with filler count lo, lo+step, ... <= hi\n"
                    "  -H  request transparent huge pages (native only; enclaves use 4 KB)\n",
                    argv[0]);
            return 1;
        }
    }

    kb_init();
    calib_t c = bench_calibrate("chase", kb_calib_timer);
    printf("# chase mb_per_chain=%zu iters=%llu thp=%d\n", mb, (unsigned long long)iters, thp);

    if (kb_setup(NULL, 0, mb, seed, thp) != 0) {
        fprintf(stderr, "chain setup failed (out of memory? enclave heap is ENCLAVE_HEAP in the Makefile)\n");
        return 1;
    }

    uint64_t n = kb_count();
    char (*kind)[32] = malloc(n * sizeof(*kind));
    uint64_t *fill = malloc(n * sizeof(*fill)), unused;
    for (uint64_t e = 0; e < n; e++)
        kb_entry(e, kind[e], sizeof(kind[e]), &fill[e], &unused);

    /* One full-length untimed pass: the first walk after building the chains
     * is slower (cold TLB / page-walk caches), most visibly in the enclave. */
    kb_run(0, iters);

    printf("kind,n,trial,ticks,cycles,iters,cyc_per_iter\n");
    for (int t = 0; t < trials; t++) {
        for (uint64_t e = 0; e < n; e++) {
            if (!selected(kind[e], filter) || !n_selected(fill[e], n_lo, n_hi, n_step))
                continue;
            kb_run(e, 256);   /* warm code + TLB path */
            uint64_t ticks = kb_run(e, iters);
            double cyc = ticks * c.cyc_per_tick;
            printf("%s,%llu,%d,%llu,%.0f,%llu,%.2f\n", kind[e], (unsigned long long)fill[e], t,
                   (unsigned long long)ticks, cyc, (unsigned long long)iters, cyc / iters);
        }
        fflush(stdout);
    }
    bench_recheck(&c, kb_calib_timer);
    kb_fini();
    return 0;
}
