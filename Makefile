BPFTIME_CLI := bpftime/build/tools/cli/bpftime
LIBBPF := bpftime/build/libbpf
ARCH := $(shell uname -m | sed 's/x86_64/x86/; s/aarch64/arm64/')
OUT := uprobe/.output

all: bpftime target usleep

bpftime: $(BPFTIME_CLI)

usleep: uprobe/usleep

$(BPFTIME_CLI):
	[ -d bpftime ] || git clone --recurse-submodules --shallow-submodules --depth 1 \
		https://github.com/eunomia-bpf/bpftime.git
	cmake -S bpftime -B bpftime/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
		-DBPFTIME_LLVM_JIT=OFF -DBUILD_BPFTIME_DAEMON=OFF -DBPFTIME_ENABLE_UNIT_TESTING=OFF
	ninja -C bpftime/build tools/cli/bpftime runtime/agent/libbpftime-agent.so \
		runtime/syscall-server/libbpftime-syscall-server.so

target: target.c
	$(CC) -O2 -pthread $< -o $@

uprobe/usleep: uprobe/usleep.c $(OUT)/usleep.skel.h
	$(CC) -g -Wall -I$(OUT) -I$(LIBBPF) $< $(LIBBPF)/libbpf.a -lelf -lz -o $@

$(OUT)/usleep.skel.h: $(OUT)/usleep.bpf.o
	bpftool gen skeleton $< > $@

$(OUT)/usleep.bpf.o: uprobe/usleep.bpf.c | $(BPFTIME_CLI)
	mkdir -p $(OUT)
	clang -g -O2 -target bpf -D__TARGET_ARCH_$(ARCH) \
		-Ibpftime/third_party/vmlinux/$(ARCH) -I$(LIBBPF) -c $< -o $@

clean:
	rm -rf $(OUT) uprobe/usleep target

.PHONY: all bpftime usleep clean
