# OctoApp Companion Plugin

Integrates the [OctoApp Companion Plugin](https://github.com/crysxd/OctoApp-Plugin) for Moonraker, enabling remote push notifications to OctoApp mobile apps (iOS/Android).

## What This Overlay Does

Installs the **OctoApp Companion Plugin** - a server-side Moonraker integration that:

- Provides API for OctoApp mobile apps to connect remotely
- Sends push notifications for print events (completion, progress, G-code events)
- Supports Live Activities on iOS
- Provides end-to-end encryption for Android
- Auto-registers mobile apps when they connect

**Note:** This installs the server component only. Users install the OctoApp mobile app separately on their phones.

## Implementation Plan

### Standalone Service Architecture

OctoApp runs as a **standalone service** (NOT a Moonraker component):

- Runs in separate process with own init script (`/etc/init.d/S66octoapp`)
- Connects TO Moonraker via WebSocket (not loaded BY Moonraker)
- Entry point: `python3 -m moonraker_octoapp <base64-json-config>`
- Starts after Moonraker (S66 vs S61)

**Service Pattern:**

- Based on K1/SonicPad implementation from official install.sh
- Uses start-stop-daemon with PID file
- Invokes Python module with JSON config (like official installer)

### Overlay Structure

```shell
53-octoapp-moonraker-plugin/
├── README.md
├── root
│   ├── etc
│   │   └── init.d
│   │       └── S66octoapp     # Init script for OctoApp service
│   └── home
│       └── lava
│           ├── bin
│           │   └── octoapp.sh  # Launcher script for OctoApp service
│           └── printer_data
│               ├── config
│               │   └── octoapp-service-config.json # Bootstrap config for OctoApp
└── scripts
    └── 01-install-octoapp.sh  # Installer script
```

### Processing Order

1. **pre-scripts/01-clone-octoapp.sh** - Clone repo to `tmp/octoapp-plugin/`
2. **scripts/01-install-octoapp.sh** - Copy to rootfs, install base Python deps
3. **root/etc/init.d/S66octoapp** - Copied to rootfs as service init script

### Installation Strategy

**Build-time (overlay execution):**

- Clone OctoApp-Plugin repository to `tmp/` (pre-scripts)
- Copy repo source to `/home/lava/octoapp` in rootfs (scripts)
- Install ALL Python dependencies into system Python via chroot pip3 (scripts)
  - Installs from `requirements.txt`
  - Installs from `requirements_try.txt` (optional deps, non-fatal)
- Add init script to `/etc/init.d/S66octoapp` (root copy)

**All dependencies are baked into the read-only squashfs firmware at build time.**

**Runtime (init script):**

- Check if OctoApp plugin is enabled via extended.cfg
- Start OctoApp service using system `/usr/bin/python3`
- No virtual environment creation
- No package installation
- Everything is already installed in the firmware

### File Locations

**In squashfs (read-only):**

- `/home/lava/octoapp/` - OctoApp-Plugin source code
- `/etc/init.d/S66octoapp` - Init script
- `/usr/lib/python3.11/site-packages/` - All OctoApp Python dependencies (baked in)

**In /userdata (persistent, if needed):**

- `/home/lava/printer_data/octoapp` - Runtime secrets (printer ID, private key)
- `/home/lava/printer_data/config/octoapp.conf` - Plugin configuration (if created)
- `/home/lava/printer_data/logs/octoapp.log` - Service logs

**Runtime:**

- `/var/run/octoapp.pid` - Process ID file

### Service Details

**Init script:** `/etc/init.d/S66octoapp`

- Numbering: S66 (runs after S61moonraker)
- User: lava (via `start-stop-daemon -c lava`)
- PID file: `/var/run/octoapp.pid`

**Entry point:**

```bash
/usr/bin/python3 /home/lava/octoapp/moonraker_octoapp/main.py
```

**Command line args (if needed):**

- Moonraker config: `/home/lava/printer_data/config/moonraker.conf`
- Data directory: `/userdata/extended/.octoapp`

### Dependencies

**Python packages (installed into system Python during build):**

- All packages from `requirements.txt` (websocket-client, cryptography, apprise, etc.)
- All packages from `requirements_try.txt` (pycryptodome for E2EE, optional)
- Installed via `chroot_firmware.sh` into `/usr/lib/python3.11/site-packages/`
- Baked into read-only squashfs

**System requirements (already in U1 firmware):**

- Python 3.11
- pip3
- Moonraker (S61moonraker)

### Integration with Moonraker

OctoApp connects to Moonraker via:

- WebSocket at `ws://localhost:7125/websocket`
- Monitors printer state changes
- Reads webcam config from Moonraker
- Can be managed via Moonraker update manager

### Mobile App Connection

Users connect the OctoApp mobile app by:

1. Installing OctoApp on iOS/Android
2. Scanning QR code from Mainsail/Fluidd
3. App auto-registers with the companion plugin
4. Receives push notifications for print events

### Update Strategy

OctoApp-Plugin is **baked into the firmware** and updates via:

- **Firmware updates** - Flash new firmware with updated OctoApp overlay
- **Manual updates** - Advanced users can modify `/home/lava/octoapp/` (but changes lost on firmware update)

**Note:** Source code lives in read-only squashfs. To update, rebuild firmware with new SHA in pre-scripts.

## Implementation Notes

### Why System Python Instead of Venv?

- Matches existing firmware pattern (Klipper, Moonraker, Apprise all use system Python)
- All dependencies baked into squashfs at build time
- Simpler init script - no venv management
- Consistent with other overlays (51-apprise, 99-remote-screen)

### Why Bake Everything at Build Time?

- No runtime package installation overhead
- No first-boot delays
- Reproducible builds with pinned versions
- SBOM tracking for supply chain security

## Testing

After flashing firmware with this overlay:

1. SSH into printer
2. Check service status: `/etc/init.d/S66octoapp status` (if implemented)
3. Check logs: `tail -f /userdata/printer_data/logs/octoapp.log`
4. Check process: `ps | grep moonraker_octoapp`
5. Test from mobile: Install OctoApp and scan QR code from web UI

## References

- [OctoApp GitHub](https://github.com/crysxd/OctoApp-Plugin)
- [OctoApp Wiki](https://github.com/crysxd/OctoApp-Plugin/wiki)
- License: AGPL-3.0
