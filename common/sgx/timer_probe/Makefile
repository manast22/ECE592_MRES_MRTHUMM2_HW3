# SGX timer probe, built with the Intel SGX SDK (hardware, debug enclave).
# LVI mitigations (MITIGATION-CVE-2020-0551) are deliberately NOT enabled:
# they insert lfence after loads, which would change what we measure.
SGX_SDK ?= /opt/intel/sgxsdk
COMMON  := ../..
EDGER8R := $(SGX_SDK)/bin/x64/sgx_edger8r
SIGNER  := $(SGX_SDK)/bin/x64/sgx_sign
SGX_KEY ?= $(HOME)/.config/sgx/enclave_private.pem

CFLAGS := -m64 -O2 -g -Wall -Wextra -I$(COMMON)

ENCLAVE_CFLAGS := $(CFLAGS) -nostdinc -fvisibility=hidden -fpie -ffunction-sections -fdata-sections \
	-fstack-protector-strong -I$(SGX_SDK)/include -I$(SGX_SDK)/include/tlibc
ENCLAVE_LDFLAGS := -Wl,-z,relro,-z,now,-z,noexecstack \
	-Wl,--no-undefined -nostdlib -nodefaultlibs -nostartfiles -L$(SGX_SDK)/lib64 \
	-Wl,--whole-archive -lsgx_trts -Wl,--no-whole-archive \
	-Wl,--start-group -lsgx_tstdc -lsgx_tcxx -lsgx_tcrypto -lsgx_tservice -Wl,--end-group \
	-Wl,-Bstatic -Wl,-Bsymbolic -Wl,--no-undefined \
	-Wl,-pie,-eenclave_entry -Wl,--export-dynamic \
	-Wl,--defsym,__ImageBase=0 -Wl,--gc-sections \
	-Wl,--version-script=enclave.lds

APP_CFLAGS  := $(CFLAGS) -fPIC -I$(SGX_SDK)/include
APP_LDFLAGS := -L$(SGX_SDK)/lib64 -lsgx_urts -lpthread

all: probe_app enclave.signed.so

probe_t.c probe_t.h: probe.edl
	$(EDGER8R) --trusted $< --search-path $(SGX_SDK)/include
probe_u.c probe_u.h: probe.edl
	$(EDGER8R) --untrusted $< --search-path $(SGX_SDK)/include

enclave.so: enclave.c probe_t.c $(COMMON)/calib.S probe_t.h enclave.lds
	$(CC) $(ENCLAVE_CFLAGS) -I. -o $@ enclave.c probe_t.c $(COMMON)/calib.S $(ENCLAVE_LDFLAGS)

enclave.signed.so: enclave.so enclave.config.xml | $(SGX_KEY)
	$(SIGNER) sign -key $(SGX_KEY) -enclave $< -out $@ -config enclave.config.xml

probe_app: app.c probe_u.c probe_u.h $(COMMON)/bench.c $(COMMON)/calib.S
	$(CC) $(APP_CFLAGS) -I. -o $@ app.c probe_u.c $(COMMON)/bench.c $(COMMON)/calib.S $(APP_LDFLAGS)

# SGX requires a 3072-bit RSA key with public exponent 3. Kept outside the repo.
$(SGX_KEY):
	mkdir -p $(dir $@)
	openssl genrsa -3 -out $@ 3072

clean:
	rm -f probe_app enclave.so enclave.signed.so probe_t.* probe_u.*

.PHONY: all clean
