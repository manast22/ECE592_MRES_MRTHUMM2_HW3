# TSC -> cycle calibration kernels.
# Uses `add reg,reg` (not add-immediate): some recent Intel cores can collapse
# dependent add-immediate chains at rename, which would break the 1-cycle
# assumption.

    .text

# void calib_add_chain(uint64_t iters)
    .globl calib_add_chain
    .p2align 6
calib_add_chain:
    mov     $1, %edx
    xor     %eax, %eax
1:
    .rept 1000
    add     %rdx, %rax
    .endr
    dec     %rdi
    jnz     1b
    ret

# void calib_imul_chain(uint64_t iters)
    .globl calib_imul_chain
    .p2align 6
calib_imul_chain:
    mov     $1, %edx
    mov     $1, %eax
1:
    .rept 1000
    imul    %rdx, %rax
    .endr
    dec     %rdi
    jnz     1b
    ret

    .section .note.GNU-stack,"",@progbits
