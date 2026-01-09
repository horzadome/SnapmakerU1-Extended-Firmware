---
title: Service Management Using Supervisord
---

# Service Management Using Supervisord

**Available in: Extended firmware**

Allows starting and stopping services directly from Fluidd, Mainsail or other Moonraker-compatible application.

## How It Works

This overlay installs [Supervisord](https://supervisord.org/) and configures Moonraker API to interact with it. 
Moonraker then exposes those controls to Fluidd/Mainsail/Apps, allowing users to start/stop/restart services from them. 

Other overlays may add their services to be managed by Supervisord by creating drop-in configuration files in `/etc/supervisord.d/` directory.

However, services are not automatically exposed to Fluidd/Mainsail/Apps by default - read how to enable service management in the Usage section below.

## Usage

To have services available for management in Fluidd/Mainsail/Apps, they must be explicitly allowed in Moonraker allow-list file `/home/lava/printer_data/moonraker.asvc`.

User will need to edit this file to list all services they want to manage via Moonraker.
Example `moonraker.asvc` to allow management of `remote_screen` service:

```text
klipper_mcu
webcamd
MoonCord
KlipperScreen
moonraker-telegram-bot
moonraker-obico
sonar
crowsnest
octoeverywhere
ratos-configurator
nginx
octoapp_plugin
remote_screen
```

Notice that we added `remote_screen` at the end of Moonraker's default list to allow management of the Remote Screen service.
To learn more about this, please check the [Moonraker Allowed Services documentation](https://moonraker.readthedocs.io/en/latest/configuration/#allowed-services).
