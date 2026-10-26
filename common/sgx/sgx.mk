# SGX build rules (Intel SGX SDK, hardware debug enclave). Included by
# common.mk. For an experiment with BIN = q1_bench this builds
#   q1_bench_sgx              host driver linked with kb_sgx.c
#   q1_bench_sgx.enclave.so   signed enclave: KT_SRC + enclave_main.c
#
# LVI mitigations (MITIGATION-CVE-2020-0551) are deliberately NOT enabled:
# they insert lfence after loads, which would serialize the very loads the
# out-of-order experiments measure.

SGX_SDK  ?= /opt/intel/sgxsdk
SGX_DIR  := $(COMMON)/sgx
EDGER8R  := $(SGX_SDK)/bin/x64/sgx_edger8r
SIGNER   := $(SGX_SDK)/bin/x64/sgx_sign
SGX_KEY  ?= $(HOME)/.config/sgx/enclave_private.pem
ENCLAVE_HEAP ?= 0x4000000

ENCLAVE_CFLAGS := -m64 -O2 -g -Wall -Wextra -DIN_ENCLAVE -I$(COMMON) -I. \
	-nostdinc -fvisibility=hidden -fpie -ffunction-sections -fdata-sections \
	-fstack-protector-strong -I$(SGX_SDK)/include -I$(SGX_SDK)/include/tlibc
ENCLAVE_LDFLAGS := -Wl,-z,relro,-z,now,-z,noexecstack \
	-Wl,--no-undefined -nostdlib -nodefaultlibs -nostartfiles -L$(SGX_SDK)/lib64 \
	-Wl,--whole-archive -lsgx_trts -Wl,--no-whole-archive \
	-Wl,--start-group -lsgx_tstdc -lsgx_tcxx -lsgx_tcrypto -lsgx_tservice -Wl,--end-group \
	-Wl,-Bstatic -Wl,-Bsymbolic -Wl,--no-undefined \
	-Wl,-pie,-eenclave_entry -Wl,--export-dynamic \
	-Wl,--defsym,__ImageBase=0 -Wl,--gc-sections \
	-Wl,--version-script=$(SGX_DIR)/enclave.lds

SGX_BIN := $(BIN)_sgx

sgx: $(SGX_BIN) $(SGX_BIN).enclave.so

kb_t.c kb_t.h: $(SGX_DIR)/kb.edl
	$(EDGER8R) --trusted $< --search-path $(SGX_SDK)/include
kb_u.c kb_u.h: $(SGX_DIR)/kb.edl
	$(EDGER8R) --untrusted $< --search-path $(SGX_SDK)/include

$(SGX_BIN).unsigned.so: $(KT_SRC) $(SGX_DIR)/enclave_main.c kb_t.c $(COMMON)/calib.S kb_t.h $(COMMON)/kt.h
	$(CC) $(ENCLAVE_CFLAGS) -o $@ $(filter %.c %.S,$^) $(ENCLAVE_LDFLAGS)

$(SGX_BIN).config.xml: $(SGX_DIR)/enclave.config.xml.in Makefile
	sed 's/@HEAP@/$(ENCLAVE_HEAP)/' $< > $@

$(SGX_BIN).enclave.so: $(SGX_BIN).unsigned.so $(SGX_BIN).config.xml | $(SGX_KEY)
	$(SIGNER) sign -key $(SGX_KEY) -enclave $< -out $@ -config $(SGX_BIN).config.xml > $@.log 2>&1 || { cat $@.log; false; }

$(SGX_BIN): $(DRIVER_SRC) $(SGX_DIR)/kb_sgx.c kb_u.c $(COMMON_SRC) kb_u.h $(COMMON)/kbackend.h
	$(CC) $(CFLAGS) -I. -I$(SGX_SDK)/include -o $@ $(filter %.c %.S,$^) -L$(SGX_SDK)/lib64 -lsgx_urts -lpthread

# SGX requires a 3072-bit RSA key with public exponent 3. Kept outside the repo.
$(SGX_KEY):
	mkdir -p $(dir $@)
	openssl genrsa -3 -out $@ 3072

.PHONY: sgx clean-sgx
clean-sgx:
	rm -f $(SGX_BIN) $(SGX_BIN).unsigned.so $(SGX_BIN).enclave.so $(SGX_BIN).enclave.so.log $(SGX_BIN).config.xml kb_t.[ch] kb_u.[ch]
