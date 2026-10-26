# Shared build rules. Each experiment's bench/Makefile sets
#   BIN         benchmark name (e.g. q1_bench)
#   DRIVER_SRC  host driver: CLI, data generation, output (uses kbackend.h)
#   KT_SRC      timed part: kernels + kt_* functions (common/kt.h); compiled
#               into the native binary AND into the SGX enclave
#   GENERATED   files `make clean` should remove (optional)
#   ENCLAVE_HEAP  enclave heap size (optional, default 64 MiB)
# and then includes this file.
#   make        -> native binary $(BIN)
#   make sgx    -> $(BIN)_sgx + $(BIN)_sgx.enclave.so
.DEFAULT_GOAL := all
COMMON := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

CC      := gcc
CFLAGS  ?= -O2 -g -Wall -Wextra
CFLAGS  += -I$(COMMON)
COMMON_SRC := $(COMMON)/bench.c $(COMMON)/calib.S

all: $(BIN)

$(BIN): $(DRIVER_SRC) $(KT_SRC) $(COMMON)/kb_native.c $(COMMON_SRC) $(COMMON)/kt.h $(COMMON)/kbackend.h
	$(CC) $(CFLAGS) -o $@ $(filter %.c %.S,$^)

include $(COMMON)/sgx/sgx.mk

clean: clean-sgx
	rm -f $(BIN) $(GENERATED)

.PHONY: all clean
