# Shared build rules. Each experiment's bench/Makefile sets
#   BIN         benchmark name (e.g. q1_bench)
#   DRIVER_SRC  host driver: CLI, data generation, output (uses kbackend.h)
#   KT_SRC      timed part: kernels + kt_* functions (common/kt.h); compiled
#               into the native binary AND into the SGX enclave
#   GENERATED   files `make clean` should remove (optional)
#   ENCLAVE_HEAP  enclave heap size (optional, default 64 MiB)
# and then includes this file. Generated kernels should depend on .gen_args
# (rewritten only when GEN_ARGS changes, e.g. a new ZOOM window from zoom.sh),
# and Makefiles may use the helpers below in recursively expanded (=) variables.
#   make        -> native binary $(BIN)
#   make sgx    -> $(BIN)_sgx + $(BIN)_sgx.enclave.so
.DEFAULT_GOAL := all
COMMON := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

CC      := gcc
CFLAGS  ?= -O2 -g -Wall -Wextra
CFLAGS  += -I$(COMMON)
COMMON_SRC := $(COMMON)/bench.c $(COMMON)/calib.S

comma := ,
space := $(empty) $(empty)
# CPU features of the build machine (= the machine the benchmark runs on).
CPU_FLAGS := $(shell grep -m1 '^flags' /proc/cpuinfo)
has_flag = $(filter $(1),$(CPU_FLAGS))
# "470:530,404:460" -> "470:530:1,404:460:1" (step-1 windows for gen_chase.py --n)
step1 = $(subst $(space),$(comma),$(foreach w,$(subst $(comma), ,$(1)),$(w):1))

all: $(BIN)

.gen_args: FORCE
	@echo '$(GEN_ARGS)' | cmp -s - $@ 2>/dev/null || echo '$(GEN_ARGS)' > $@
FORCE:

$(BIN): $(DRIVER_SRC) $(KT_SRC) $(COMMON)/kb_native.c $(COMMON_SRC) $(COMMON)/kt.h $(COMMON)/kbackend.h
	$(CC) $(CFLAGS) -o $@ $(filter %.c %.S,$^)

include $(COMMON)/sgx/sgx.mk

clean: clean-sgx
	rm -f $(BIN) $(GENERATED) .gen_args

.PHONY: all clean FORCE
