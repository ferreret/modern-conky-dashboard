#!/usr/bin/env bash
#
# Modern Conky Dashboard - Start Script
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/conky.conf"

# Kill any existing modern conky instance
pkill -f "conky.*modern/conky.conf" 2>/dev/null
sleep 0.5

# Optional: also stop LCC if running
if [[ "$1" == "--replace" ]]; then
    pkill -f "conky.*lcc/conky.conf" 2>/dev/null
    sleep 0.3
fi

# Start
conky -c "$CONF" -d &
echo "Modern Conky dashboard started (PID: $!)"
