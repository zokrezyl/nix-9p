BUILD_DIR ?= build
TINYEMU_URL = https://bellard.org/tinyemu/tinyemu-2019-12-21.tar.gz
JSLINUX_URL = https://bellard.org/jslinux
TOOL_BUILD_DIR = $(BUILD_DIR)/_vfsync-build
VFSYNC_DIR = $(BUILD_DIR)/vfsync/u/os/nix-9p
JSLINUX_DIR = $(BUILD_DIR)/jslinux

JSLINUX_FILES = jslinux.js term.js x86_64emu-wasm.js x86_64emu-wasm.wasm kernel-x86_64.bin

.PHONY: all clean

all: $(VFSYNC_DIR)/head $(JSLINUX_DIR)/nix-9p.cfg jslinux-files $(JSLINUX_DIR)/index.html $(BUILD_DIR)/index.html

# --- Build tools ---

$(TOOL_BUILD_DIR)/build_filelist:
	mkdir -p $(TOOL_BUILD_DIR)
	curl -sL $(TINYEMU_URL) -o $(TOOL_BUILD_DIR)/tinyemu.tar.gz
	cd $(TOOL_BUILD_DIR) && tar xzf tinyemu.tar.gz && rm tinyemu.tar.gz
	cd $(TOOL_BUILD_DIR)/tinyemu-2019-12-21 && gcc -o ../build_filelist build_filelist.c fs_utils.c cutils.c -I.

# --- Nix rootfs ---

$(BUILD_DIR)/rootfs-path.txt:
	mkdir -p $(BUILD_DIR)
	nix build .#default --no-link --print-out-paths > $@

# --- vfsync filesystem ---

$(VFSYNC_DIR)/head: $(TOOL_BUILD_DIR)/build_filelist $(BUILD_DIR)/rootfs-path.txt
	mkdir -p $(VFSYNC_DIR)
	$(TOOL_BUILD_DIR)/build_filelist -m 2000 "$$(cat $(BUILD_DIR)/rootfs-path.txt)" $(VFSYNC_DIR)

# --- JSLinux emulator files ---

.PHONY: jslinux-files
jslinux-files: | $(JSLINUX_DIR)
	@for f in $(JSLINUX_FILES); do \
		if [ ! -f "$(JSLINUX_DIR)/$$f" ]; then \
			echo "Downloading $$f..."; \
			curl -sL "$(JSLINUX_URL)/$$f" -o "$(JSLINUX_DIR)/$$f"; \
		fi; \
	done

$(JSLINUX_DIR):
	mkdir -p $(JSLINUX_DIR)

# --- Config ---

$(JSLINUX_DIR)/nix-9p.cfg: | $(JSLINUX_DIR)
	@printf '{\n    version: 1,\n    machine: "pc",\n    memory_size: 256,\n    kernel: "kernel-x86_64.bin",\n    cmdline: "loglevel=3 console=hvc0 root=root rootfstype=9p rootflags=trans=virtio ro",\n    fs0: { file: "../vfsync/u/os/nix-9p" },\n    eth0: { driver: "user" },\n}\n' > $@

# --- Index page ---

$(JSLINUX_DIR)/index.html: index.html | $(JSLINUX_DIR)
	cp index.html $(JSLINUX_DIR)/index.html

$(BUILD_DIR)/index.html:
	@echo '<meta http-equiv="refresh" content="0;url=jslinux/">' > $@

clean:
	rm -rf $(BUILD_DIR)
