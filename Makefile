BUILD_DIR ?= build
TINYEMU_URL = https://bellard.org/tinyemu/tinyemu-2019-12-21.tar.gz
TOOL_BUILD_DIR = $(BUILD_DIR)/_vfsync-build
OUTPUT_DIR = $(BUILD_DIR)/vfsync/u/os/nix-9p

.PHONY: all clean

all: $(OUTPUT_DIR)/head $(BUILD_DIR)/jslinux/nix-9p.cfg

$(TOOL_BUILD_DIR)/build_filelist:
	mkdir -p $(TOOL_BUILD_DIR)
	curl -sL $(TINYEMU_URL) -o $(TOOL_BUILD_DIR)/tinyemu.tar.gz
	cd $(TOOL_BUILD_DIR) && tar xzf tinyemu.tar.gz && rm tinyemu.tar.gz
	cd $(TOOL_BUILD_DIR)/tinyemu-2019-12-21 && gcc -o ../build_filelist build_filelist.c fs_utils.c cutils.c -I.

$(BUILD_DIR)/rootfs-path.txt:
	mkdir -p $(BUILD_DIR)
	nix build .#default --no-link --print-out-paths > $@

$(OUTPUT_DIR)/head: $(TOOL_BUILD_DIR)/build_filelist $(BUILD_DIR)/rootfs-path.txt
	mkdir -p $(OUTPUT_DIR)
	$(TOOL_BUILD_DIR)/build_filelist -m 2000 "$$(cat $(BUILD_DIR)/rootfs-path.txt)" $(OUTPUT_DIR)

$(BUILD_DIR)/jslinux/nix-9p.cfg:
	mkdir -p $(BUILD_DIR)/jslinux
	@printf '{\n    version: 1,\n    machine: "pc",\n    memory_size: 256,\n    kernel: "kernel-x86_64.bin",\n    cmdline: "loglevel=3 console=hvc0 root=root rootfstype=9p rootflags=trans=virtio ro",\n    fs0: { file: "../vfsync/u/os/nix-9p" },\n}\n' > $@

clean:
	rm -rf $(BUILD_DIR)
