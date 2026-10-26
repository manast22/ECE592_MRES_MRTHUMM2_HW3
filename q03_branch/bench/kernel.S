# Q3 kernel: one data-dependent conditional branch per array element.
#
# uint64_t branch_kernel(const uint8_t *pat, uint64_t len, uint64_t passes)
#   for each pass, for each i: if (pat[i]) taken-path else fall-through-path
# Both paths do one add, so only prediction accuracy differs between patterns.
# Written in asm so the compiler cannot turn the branch into a cmov.
# Returns the number of taken branches.

    .text
    .globl branch_kernel
    .p2align 6
branch_kernel:
    xor     %eax, %eax          # taken count
    xor     %r9d, %r9d          # not-taken count
    mov     $1, %r10d
.Lpass:
    xor     %ecx, %ecx
    .p2align 5
.Lloop:
    movzbl  (%rdi,%rcx), %r8d
    test    %r8d, %r8d
    jnz     .Ltaken             # <-- the branch under test
    add     %r10, %r9
    jmp     .Ljoin
.Ltaken:
    add     %r10, %rax
.Ljoin:
    inc     %rcx
    cmp     %rsi, %rcx
    jb      .Lloop
    dec     %rdx
    jnz     .Lpass
    ret

    .section .note.GNU-stack,"",@progbits
