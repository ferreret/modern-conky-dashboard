#!/bin/bash
# Run cava and write latest frame to file for conky to read
CONF="$(dirname "$0")/../cava.conf"
OUTPUT="/tmp/conky-cava.txt"

if ! command -v cava &>/dev/null; then
    exit 1
fi

exec cava -p "$CONF" 2>/dev/null | while IFS= read -r line; do
    echo "$line" > "$OUTPUT"
done
