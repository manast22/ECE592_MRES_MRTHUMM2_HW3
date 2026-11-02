/* Which extended register state does this process have in use?
 * xgetbv(1) returns XINUSE; bit 7 is the upper vector state (zmm16-31 / ymm16-31).
 * Native evidence for the ymm knee difference. The enclave counterpart is the
 * "enclave XINUSE" line printed by common/sgx/timer_probe/probe_app.
 * usage: make xinuse && ./xinuse
 *        GLIBC_TUNABLES=glibc.cpu.hwcaps=-AVX512F,-AVX512VL,-AVX512BW,-AVX512DQ,-EVEX ./xinuse */
#include <stdint.h>
#include <stdio.h>

int main(void)
{
    uint32_t a, d;
    __asm__ volatile("xgetbv" : "=a"(a), "=d"(d) : "c"(1));
    printf("XINUSE=%#x hi16_zmm_in_use=%u\n", a, a >> 7 & 1);
    (void)d;
    return 0;
}
