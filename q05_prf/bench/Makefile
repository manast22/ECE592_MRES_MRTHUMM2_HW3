BIN        := q5_bench
DRIVER_SRC := ../../common/chase/chase_main.c
KT_SRC     := ../../common/chase/chase_kt.c kernels.S
GENERATED  := kernels.S xinuse
# register-writing filler: integer, ymm vector, and alternating int/ymm, plus
# integer controls: flags-free lea (reg+imm), independent lea, independent flags-writing
# andn, independent flags-free shlx (no immediate), and reg+reg lea (no immediate);
# ymm_hi = ymm filler after writing ymm16-31 (tests the native-vs-SGX ymm knee shift).
# Kinds needing a CPU feature are only built where the CPU has it (andn: BMI1,
# shlx: BMI2, ymm_hi: AVX-512VL); `make ZMM=1` adds an AVX-512 zmm kind.
# Coarse sweep 0..640 step 8 (run.sh) plus step-1 windows around the knees (zoom.sh
# sets ZOOM from this machine's coarse results; the default is Sapphire Rapids').
KINDS = int,ymm,mix,int_lea,int_ind,int_lea2$(if $(call has_flag,bmi1),$(comma)int_andn)$(if \
        $(call has_flag,bmi2),$(comma)int_shlx)$(if $(call has_flag,avx512vl),$(comma)ymm_hi)$(if \
        $(ZMM),$(comma)zmm)
ZOOM      ?= 196:280,404:460
GEN_ARGS   = --kinds $(KINDS) --n 0:640:8,$(call step1,$(ZOOM))
# two 128 MiB chains + 8 MiB shuffle buffer, in the enclave heap
ENCLAVE_HEAP := 0x12000000

include ../../common/common.mk

kernels.S: $(COMMON)/chase/gen_chase.py .gen_args
	python3 $< $(GEN_ARGS) > $@

xinuse: xinuse.c
	$(CC) $(CFLAGS) -o $@ $<
