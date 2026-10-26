BIN        := q5_bench
DRIVER_SRC := ../../common/chase/chase_main.c
KT_SRC     := ../../common/chase/chase_kt.c kernels.S
GENERATED  := kernels.S
# register-writing filler: integer, ymm vector, and alternating int/ymm
GEN_ARGS   := --kinds int,ymm,mix --n 0:640:8
# two 128 MiB chains + 8 MiB shuffle buffer, in the enclave heap
ENCLAVE_HEAP := 0x12000000

include ../../common/common.mk

kernels.S: $(COMMON)/chase/gen_chase.py Makefile
	python3 $< $(GEN_ARGS) > $@
