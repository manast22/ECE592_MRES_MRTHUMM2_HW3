/* SGX backend: kernels live in <exe>.enclave.so and are reached via ECALLs.
 * All timing is done with rdtsc *inside* the enclave (verified to work on
 * this platform by common/sgx/timer_probe), so the ~16k-cycle ECALL cost is
 * never part of a measurement. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "kb_u.h"
#include "kbackend.h"
#include "sgx_urts.h"

static sgx_enclave_id_t eid;

static void check(sgx_status_t s, const char *what)
{
    if (s != SGX_SUCCESS) {
        fprintf(stderr, "%s failed: sgx_status 0x%x\n", what, s);
        exit(1);
    }
}

static uint64_t sgx_calib(int kind, uint64_t iters)
{
    uint64_t ticks;
    check(ecall_calib(eid, &ticks, kind, iters), "ecall_calib");
    return ticks;
}

calib_timer_fn kb_calib_timer = sgx_calib;

void kb_init(void)
{
    char path[4096];
    ssize_t n = readlink("/proc/self/exe", path, sizeof(path) - 16);
    if (n < 0) {
        perror("readlink /proc/self/exe");
        exit(1);
    }
    strcpy(path + n, ".enclave.so");

    if (access("/dev/sgx_enclave", R_OK | W_OK) != 0) {
        perror("/dev/sgx_enclave");
        fprintf(stderr, "hint: your login session must be in the 'sgx' group (id -nG); "
                        "log in again or use `sg sgx -c ...`\n");
        exit(1);
    }
    check(sgx_create_enclave(path, 1 /* debug */, NULL, NULL, &eid, NULL), "sgx_create_enclave");
    printf("# backend sgx enclave=%s debug=1 runtime=intel-sgx-sdk\n", strrchr(path, '/') + 1);
}

void kb_fini(void)
{
    sgx_destroy_enclave(eid);
}

uint64_t kb_count(void)
{
    uint64_t n;
    check(ecall_count(eid, &n), "ecall_count");
    return n;
}

void kb_entry(uint64_t i, char *name, size_t cap, uint64_t *a, uint64_t *b)
{
    check(ecall_entry(eid, i, name, cap, a, b), "ecall_entry");
}

int kb_setup(const void *data, size_t len, uint64_t p0, uint64_t p1, uint64_t p2)
{
    int rc;
    check(ecall_setup(eid, &rc, data, len, p0, p1, p2), "ecall_setup");
    return rc;
}

uint64_t kb_run(uint64_t i, uint64_t iters)
{
    uint64_t ticks;
    check(ecall_run(eid, &ticks, i, iters), "ecall_run");
    return ticks;
}
