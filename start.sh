#!/usr/bin/env bash
#
# Modern Conky Dashboard - Start Script
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/conky.conf"

# Kill any existing instances
pkill -f "conky.*modern/conky.conf" 2>/dev/null
[ -f /tmp/conky-cava.pid ] && kill "$(cat /tmp/conky-cava.pid)" 2>/dev/null

# Optional: also stop LCC if running
if [[ "$1" == "--replace" ]]; then
    pkill -f "conky.*lcc/conky.conf" 2>/dev/null
fi

sleep 0.5

# Start cava visualizer if available
if command -v cava &>/dev/null; then
    "$SCRIPT_DIR/scripts/cava-pipe.sh" &
    echo $! > /tmp/conky-cava.pid
    echo "Cava audio visualizer started."
fi

# Pre-fetch data (don't wait for these)
"$SCRIPT_DIR/scripts/weather.sh" 2>/dev/null &
"$SCRIPT_DIR/scripts/calendar.sh" 2>/dev/null &
"$SCRIPT_DIR/scripts/media.sh" 2>/dev/null &

# Start conky
conky -c "$CONF" -d &
echo "Modern Conky dashboard started (PID: $!)"
