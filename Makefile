include vars.mk

all: tools

# ================= Build Tools =================

DEBUG_FIRMWARE_FILE := firmware/firmware_debug.bin
CUSTOM_FIRMWARE_FILE := firmware/firmware_custom.bin

$(DEBUG_FIRMWARE_FILE): firmware/$(FIRMWARE_FILE) tools
	./scripts/enable_debug_misc.sh $< tmp/debug $@

$(CUSTOM_FIRMWARE_FILE): firmware/$(FIRMWARE_FILE) tools
	./scripts/create_custom_firmware.sh $< tmp/custom $@

custom_firmware: $(CUSTOM_FIRMWARE_FILE)
debug_firmware: $(DEBUG_FIRMWARE_FILE)
extract_firmware: firmware/$(FIRMWARE_FILE) tools
	./scripts/extract_squashfs.sh $< tmp/extracted

# ================= Tools =================

.PHONY: tools
tools: tools/rk2918_tools tools/upfile

tools/%: FORCE
	make -C $@

# =============== Firmware ===============

firmware: firmware/$(FIRMWARE_FILE)

firmware/$(FIRMWARE_FILE):
	@mkdir -p firmware
	wget -O $@ "https://public.resource.snapmaker.com/firmware/U1/$(FIRMWARE_FILE)"
	ln -sf $@ firmware/firmware.bin

# ================= Test =================

test:
	make -C tools test FIRMWARE_FILE=$(CURDIR)/firmware/$(FIRMWARE_FILE)

# ================= Helpers =================

.PHONY: FORCE
FORCE:
