# Q1 kernels: each runs `iters` iterations of a 1000-instruction block.
#   *_dep   : one dependency chain   -> bounded by latency
#   *_indep : 8 interleaved chains   -> bounded by issue/execute throughput
# All operands are registers (no immediates) so rename-time tricks on
# add-immediate cannot shortcut the chain.

    .text

# void add_dep(uint64_t iters)
    .globl add_dep
    .p2align 6
add_dep:
    mov     $1, %edx
    xor     %eax, %eax
1:
    .rept 1000
    add     %rdx, %rax
    .endr
    dec     %rdi
    jnz     1b
    ret

# void add_indep(uint64_t iters)
    .globl add_indep
    .p2align 6
add_indep:
    push    %rbx
    mov     $1, %edx
1:
    .rept 125
    add     %rdx, %rax
    add     %rdx, %rbx
    add     %rdx, %rcx
    add     %rdx, %rsi
    add     %rdx, %r8
    add     %rdx, %r9
    add     %rdx, %r10
    add     %rdx, %r11
    .endr
    dec     %rdi
    jnz     1b
    pop     %rbx
    ret

# void imul_dep(uint64_t iters)
    .globl imul_dep
    .p2align 6
imul_dep:
    mov     $1, %edx
    mov     $1, %eax
1:
    .rept 1000
    imul    %rdx, %rax
    .endr
    dec     %rdi
    jnz     1b
    ret

# void imul_indep(uint64_t iters)
    .globl imul_indep
    .p2align 6
imul_indep:
    push    %rbx
    mov     $1, %edx
1:
    .rept 125
    imul    %rdx, %rax
    imul    %rdx, %rbx
    imul    %rdx, %rcx
    imul    %rdx, %rsi
    imul    %rdx, %r8
    imul    %rdx, %r9
    imul    %rdx, %r10
    imul    %rdx, %r11
    .endr
    dec     %rdi
    jnz     1b
    pop     %rbx
    ret

    .section .note.GNU-stack,"",@progbits
