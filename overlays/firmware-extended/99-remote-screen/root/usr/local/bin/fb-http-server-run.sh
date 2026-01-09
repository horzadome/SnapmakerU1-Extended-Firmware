#!/bin/sh
# Wrapper script for fb-http-server that checks extended.cfg before starting
# Expects environment variables: EXTENDED_CFG, FB_DEVICE, TOUCH_DEVICE, HTML_TEMPLATE, PORT, BIND

# Set defaults for environment variables
EXTENDED_CFG="${EXTENDED_CFG:-/home/lava/printer_data/config/extended/extended.cfg}"
FB_DEVICE="${FB_DEVICE:-/dev/fb0}"
TOUCH_DEVICE="${TOUCH_DEVICE:-/dev/input/event0}"
HTML_TEMPLATE="${HTML_TEMPLATE:-/usr/local/share/fb-http-server/index.html}"
PORT="${PORT:-8092}"
BIND="${BIND:-127.0.0.1}"

REMOTE_SCREEN_ENABLED=$(/usr/local/bin/extended-config.py "$EXTENDED_CFG" remote_screen enabled false)

if [ "$REMOTE_SCREEN_ENABLED" != "true" ]; then
    echo "fb-http-server: remote_screen is disabled in extended.cfg"
    exit 0
fi

# Start the actual server using environment variables
exec /usr/bin/python3 /usr/local/bin/fb-http-server.py \
    --bind "$BIND" \
    --port "$PORT" \
    --fb "$FB_DEVICE" \
    --touch "$TOUCH_DEVICE" \
    --html "$HTML_TEMPLATE"
