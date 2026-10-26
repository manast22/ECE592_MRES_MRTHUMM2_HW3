/* Q3 (branch prediction) and Q15 (mispredict penalty / pipeline depth).
 *
 * Times one conditional branch per element of a pattern array.
 * Pattern specs (-p, comma separated):
 *   taken | nottaken | alt (1010...)
 *   period:P   random bits of length P, repeated (learnable if P is small)
 *   random     i.i.d. 50% taken (unlearnable)
 *   bias:F     i.i.d., taken with probability F
 *
 * Output CSV: pattern,trial,ticks,cycles,branches,taken_frac,cyc_per_branch */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "kbackend.h"

#define DEFAULT_PATTERNS \
    "taken,nottaken,alt,period:4,period:16,period:64,period:256,period:1024," \
    "period:4096,period:16384,period:65536,random"

static void fill(uint8_t *a, size_t len, const char *spec, uint64_t *seed)
{
    if (!strcmp(spec, "taken")) {
        memset(a, 1, len);
    } else if (!strcmp(spec, "nottaken")) {
        memset(a, 0, len);
    } else if (!strcmp(spec, "alt")) {
        for (size_t i = 0; i < len; i++)
            a[i] = i & 1;
    } else if (!strncmp(spec, "period:", 7)) {
        size_t p = strtoull(spec + 7, NULL, 0);
        if (p == 0 || p > len || len % p) {
            fprintf(stderr, "bad period %s (must divide %zu)\n", spec, len);
            exit(1);
        }
        for (size_t i = 0; i < p; i++)
            a[i] = xorshift64(seed) & 1;
        for (size_t i = p; i < len; i++)
            a[i] = a[i - p];
    } else if (!strcmp(spec, "random")) {
        for (size_t i = 0; i < len; i++)
            a[i] = xorshift64(seed) & 1;
    } else if (!strncmp(spec, "bias:", 5)) {
        double f = atof(spec + 5);
        uint64_t thresh = (uint64_t)(f * 18446744073709551615.0);
        for (size_t i = 0; i < len; i++)
            a[i] = xorshift64(seed) < thresh;
    } else {
        fprintf(stderr, "unknown pattern '%s'\n", spec);
        exit(1);
    }
}

int main(int argc, char **argv)
{
    int trials = 11;
    size_t len = 1 << 20;   /* 1 MiB of pattern: fits in L2, too long to memorize */
    uint64_t passes = 4, seed = 0x2545f4914f6cdd1dULL;
    char *patterns = strdup(DEFAULT_PATTERNS);
    int opt;
    while ((opt = getopt(argc, argv, "t:p:n:l:r:")) != -1) {
        switch (opt) {
        case 't': trials = atoi(optarg); break;
        case 'p': patterns = strdup(optarg); break;
        case 'n': passes = strtoull(optarg, NULL, 0); break;
        case 'l': len = strtoull(optarg, NULL, 0); break;
        case 'r': seed = strtoull(optarg, NULL, 0); break;
        default:
            fprintf(stderr, "usage: %s [-t trials] [-p patterns] [-n passes] [-l len] [-r seed]\n", argv[0]);
            return 1;
        }
    }

    /* Split the pattern list and build every array up front. */
    char *specs[64];
    int np = 0;
    for (char *s = strtok(patterns, ","); s && np < 64; s = strtok(NULL, ","))
        specs[np++] = s;
    uint8_t **arr = malloc(np * sizeof(*arr));
    double *taken_frac = malloc(np * sizeof(double));
    for (int i = 0; i < np; i++) {
        arr[i] = malloc(len);
        fill(arr[i], len, specs[i], &seed);
        size_t ones = 0;
        for (size_t j = 0; j < len; j++)
            ones += arr[i][j];
        taken_frac[i] = (double)ones / len;
    }

    kb_init();
    calib_t c = bench_calibrate("branch", kb_calib_timer);
    for (int i = 0; i < np; i++) {
        if (kb_setup(arr[i], len, i, 0, 0) != 0) {
            fprintf(stderr, "pattern setup failed (enclave heap is ENCLAVE_HEAP in the Makefile)\n");
            return 1;
        }
    }
    printf("# branch len=%zu passes=%llu\n", len, (unsigned long long)passes);
    printf("pattern,trial,ticks,cycles,branches,taken_frac,cyc_per_branch\n");

    for (int t = 0; t < trials; t++) {
        for (int i = 0; i < np; i++) {
            kb_run(i, 1);   /* train predictor, warm L2 */
            uint64_t ticks = kb_run(i, passes);
            double cyc = ticks * c.cyc_per_tick;
            double n = (double)len * passes;
            printf("%s,%d,%llu,%.0f,%.0f,%.4f,%.4f\n", specs[i], t,
                   (unsigned long long)ticks, cyc, n, taken_frac[i], cyc / n);
        }
        fflush(stdout);
    }
    bench_recheck(&c, kb_calib_timer);
    kb_fini();
    return 0;
}
