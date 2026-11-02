BIN        := q4_bench
DRIVER_SRC := ../../common/chase/chase_main.c
KT_SRC     := ../../common/chase/chase_kt.c kernels.S
GENERATED  := kernels.S
# NOP filler: coarse sweep 0..800 step 8 (run.sh), plus a step-1 window around the
# knee (zoom.sh). zoom.sh sets ZOOM from this machine's coarse results; the default
# is Sapphire Rapids' knee. The driver's -n option selects which kernels run.
ZOOM       ?= 470:530
GEN_ARGS    = --kinds nop --n 0:800:8,$(call step1,$(ZOOM))
# two 128 MiB chains + 8 MiB shuffle buffer, in the enclave heap
ENCLAVE_HEAP := 0x12000000

include ../../common/common.mk

kernels.S: $(COMMON)/chase/gen_chase.py .gen_args
	python3 $< $(GEN_ARGS) > $@
