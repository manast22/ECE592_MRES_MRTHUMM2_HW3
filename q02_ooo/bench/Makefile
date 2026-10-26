BIN        := q2_bench
DRIVER_SRC := ../../common/chase/chase_main.c
KT_SRC     := ../../common/chase/chase_kt.c kernels.S
GENERATED  := kernels.S
# single/serial/use plus back-to-back pairs with 0..192 NOPs between the loads
GEN_ARGS   := --extra --kinds nop --n 0:192:64
# two 128 MiB chains + 8 MiB shuffle buffer, in the enclave heap
ENCLAVE_HEAP := 0x12000000

include ../../common/common.mk

kernels.S: $(COMMON)/chase/gen_chase.py Makefile
	python3 $< $(GEN_ARGS) > $@
