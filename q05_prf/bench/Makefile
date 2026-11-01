BIN        := q5_bench
DRIVER_SRC := ../../common/chase/chase_main.c
KT_SRC     := ../../common/chase/chase_kt.c kernels.S
GENERATED  := kernels.S
# register-writing filler: integer, ymm vector, and alternating int/ymm, plus
# integer controls (flags-free lea, independent lea, independent flags-writing andn).
# Coarse sweep 0..640 step 8 (run.sh) plus step-1 windows around the knees (zoom.sh);
# the driver's -n option selects which to run. `make ZMM=1` adds an AVX-512 zmm kind.
comma := ,
KINDS      := int,ymm,mix,int_lea,int_ind,int_andn$(if $(ZMM),$(comma)zmm)
GEN_ARGS   := --kinds $(KINDS) --n 0:640:8,196:280:1,404:460:1
# two 128 MiB chains + 8 MiB shuffle buffer, in the enclave heap
ENCLAVE_HEAP := 0x12000000

include ../../common/common.mk

kernels.S: $(COMMON)/chase/gen_chase.py Makefile
	python3 $< $(GEN_ARGS) > $@
