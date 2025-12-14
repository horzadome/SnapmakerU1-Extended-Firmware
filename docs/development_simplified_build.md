# Simplified Containerized Build

The easiest way to build locally is using the automated build script which detects your platform and uses appropriate containerization tool.
Refer to [development.md](development.md) if you prefer to build manually.

```shell
./scripts/dev/build-locally.sh [PROFILE] [OUTPUT_FILE]
```

Examples:

```shell
# Build extended firmware (default)
./scripts/dev/build-locally.sh

# Build basic firmware
./scripts/dev/build-locally.sh basic

# Build with custom output filename
./scripts/dev/build-locally.sh extended my-custom-firmware.bin
```

## Prerequisites

### Linux

- Podman or Docker
  - `sudo apt-get install podman` or `sudo dnf install podman`
  - Follow [Docker installation guide](https://docs.docker.com/engine/install/)
- If running the script on x86_64 we also need qemu-user-static to run ARM64 containers
  - `sudo apt-get install qemu-user-static`

### macOS

- Docker Desktop for Mac: [Download here](https://docs.docker.com/desktop/install/mac-install/)

### Windows

- **Recommended**: Install WSL2 and Docker Desktop: [Docker Desktop WSL 2 backend](https://docs.docker.com/desktop/wsl/)
  - ARM64 emulation works out of the box (QEMU bundled)
- **Alternative**: Install Docker Engine directly in WSL2: [Docker Engine installation guide](https://docs.docker.com/engine/install/ubuntu/)
  - Requires manual QEMU setup: `docker run --privileged --rm tonistiigi/binfmt --install all`

## First Run

The script will take a long time to run because it first builds the builder image, downloads ~7GB of build requirements and performs the initial build.
Subsequent builds will be much faster.

## Adding New Features

1. Refer to [development.md](development.md) to learn about overlays and profiles.
2. Create a new overlay in `overlays/your-feature/`
3. Add patches in `overlays/your-feature/patches/`
   Patches are unified diff format files that modify the extracted rootfs:

   ```shell
   # After making changes to files in tmp/firmware/rootfs/
   diff -uNr original_file modified_file > overlays/your-feature/patches/01-description.patch
   ```

   Or use the helper script:

   ```shell
   ./scripts/dev/save-patch.sh
   ```

4. Add scripts in `overlays/your-feature/scripts/` (optional)
5. Add custom files in `overlays/your-feature/root/` (optional)
6. Update `Makefile` to include your overlay in the appropriate profile

## Build Output

- Firmware file: `U1_[profile]_upgrade.bin` (or your custom name)
- Build log: `build-YYYYMMDD-HHMMSS.log`
- Cached downloads: `firmware/` directory
- Build artifacts: `tmp/` directory

## Testing Changes

1. Build the firmware with your changes:
   `./scripts/dev/build-locally.sh extended test-firmware.bin`
2. Flash the firmware on your Snapmaker U1
3. Test thoroughly before submitting PRs

**Never submit PRs unless you've tested changes on actual hardware.**

## Troubleshooting

- Build Fails with "No suitable ARM64-capable tool"
  - The script couldn't find a compatible containerization tool
  - Check [Prerequisites](#prerequisites) and ensure they're installed
- ARM64 Emulation Not Working
  - On Linux x86_64

  ```shell
    sudo apt-get install qemu-user-static
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    ```

- Build Hangs on Firmware Download
  - Download manually:
    `wget -4 -O firmware/[FIRMWARE_FILE] https://public.resource.snapmaker.com/firmware/U1/[FIRMWARE_FILE]`

- Permission Denied Errors
  - The build requires root for squashfs operations so run using `sudo`:
  `sudo make build PROFILE=extended OUTPUT_FILE=U1_extended.bin`
  - Or simply use the containerized build script `./scripts/dev/build-locally.sh` which handles this automatically.
