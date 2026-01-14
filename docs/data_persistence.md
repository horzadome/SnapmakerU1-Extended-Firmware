---
title: Data Persistence
nav_order: 11
nav_icon: fas fa-database
nav_section: Basic Features
---

# Data Persistence

**Available in: Basic and Extended firmware**

By default, Snapmaker firmware resets all system changes on reboot for stability.

## Enable System Persistence

To persist system-level changes to `/etc` (SSH passwords, authorized keys, etc.):

```bash
touch /oem/.debug
```

To restore pristine system state:

```bash
rm /oem/.debug
reboot
```

## Printer Data

The `/home/lava/printer_data` directory always persists, regardless of `/oem/.debug`.

## Firmware Upgrades

**Firmware upgrades automatically remove all persisted changes and delete `/oem/.debug`.**

After upgrading, you can re-enable persistence if needed:

```bash
touch /oem/.debug
```
