/* Q1: is the processor pipelined?
 * Compare dependent vs. independent chains of the same instruction.
 * Output CSV: variant,trial,ticks,cycles,instrs,cpi,ipc */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "kbackend.h"

int main(int argc, char **argv)
{
    int trials = 11;
    uint64_t iters = 20000;   /* x1000 instructions per measurement */
    int opt;
    while ((opt = getopt(argc, argv, "t:i:")) != -1) {
        switch (opt) {
        case 't': trials = atoi(optarg); break;
        case 'i': iters = strtoull(optarg, NULL, 0); break;
        default:
            fprintf(stderr, "usage: %s [-t trials] [-i iters]\n", argv[0]);
            return 1;
        }
    }

    kb_init();
    calib_t c = bench_calibrate("q1_pipelined", kb_calib_timer);
    printf("variant,trial,ticks,cycles,instrs,cpi,ipc\n");

    uint64_t nv = kb_count(), a, b;
    char names[8][32];
    for (uint64_t v = 0; v < nv && v < 8; v++)
        kb_entry(v, names[v], sizeof(names[v]), &a, &b);

    for (int t = 0; t < trials; t++) {
        for (uint64_t v = 0; v < nv && v < 8; v++) {
            kb_run(v, iters / 10);   /* warm up i-cache / predictor */
            uint64_t ticks = kb_run(v, iters);
            double cyc = ticks * c.cyc_per_tick;
            double n = iters * 1000.0;
            printf("%s,%d,%llu,%.0f,%.0f,%.4f,%.4f\n", names[v], t,
                   (unsigned long long)ticks, cyc, n, cyc / n, n / cyc);
        }
    }
    bench_recheck(&c, kb_calib_timer);
    kb_fini();
    return 0;
}
