BIN        := q14_bench
DRIVER_SRC := q14_bench.c
KT_SRC     := q14_kt.c kernels.S
GENERATED  := kernels.S
# NOP lengths 1..15 bytes; block sizes from uop-cache resident (256) to past L1i (16384)
GEN_ARGS   := --lens 1:15 --counts 256,2048,4096,6144,8192,16384

include ../../common/common.mk

kernels.S: gen_nops.py Makefile
	python3 $< $(GEN_ARGS) > $@
