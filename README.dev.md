# Development

## Prerequisites

- Linux build environment
- make
- wget
- squashfs-tools
- C compiler (gcc)
- **Run in a container as a root**

## Quick Start

### 1. Build Tools

```bash
make tools
```

### 2. Download Firmware

```bash
make firmware
```

### 3. Extract Firmware

```bash
make extract_firmware
```

Extracted contents will be in `tmp/extracted/`

### 4. Create Custom Firmware

```bash
make custom_firmware
```

Output: `firmware/firmware_custom.bin`

### 5. Create Debug Firmware

```bash
make debug_firmware
```

Output: `firmware/firmware_debug.bin`

## Project Structure

```
.
├── custom/             Custom rootfs modifications
├── firmware/           Downloaded and generated firmware files
├── scripts/            Build and modification scripts
│   ├── create_custom_firmware.sh
│   ├── enable_debug_misc.sh
│   └── extract_squashfs.sh
├── tmp/                Temporary build artifacts
├── tools/              Firmware manipulation tools
│   ├── rk2918_tools/   Rockchip image tools
│   └── upfile/         Firmware unpacking tool
├── Makefile            Build configuration
└── vars.mk             Firmware version variables
```

## Configuration

Edit `vars.mk` to change firmware version:

```makefile
FIRMWARE_FILE=U1_0.9.0.121_20251106132913_upgrade.bin
FIRMWARE_VERSION=0.9.0.121
```

## Testing

```bash
make test
```

## Tools

### rk2918_tools

- `afptool` - Android firmware package tool
- `img_maker` - Create Rockchip images
- `img_unpack` - Unpack Rockchip images
- `mkkrnlimg` - Create kernel images

### upfile

Firmware unpacking utility for Snapmaker update files.
