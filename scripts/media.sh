#!/bin/bash
# Get current media player info via MPRIS/D-Bus
OUTPUT="/tmp/conky-media.txt"

# Try playerctl first
if command -v playerctl &>/dev/null; then
    {
        echo "STATUS=$(playerctl status 2>/dev/null || echo None)"
        echo "TITLE=$(playerctl metadata title 2>/dev/null | sed 's/ - YouTube$//')"
        echo "ARTIST=$(playerctl metadata artist 2>/dev/null)"
        echo "PLAYER=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)"
    } > "$OUTPUT"
    exit 0
fi

# Fallback: dbus-send
PLAYER=$(dbus-send --print-reply --dest=org.freedesktop.DBus \
    /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null \
    | grep -oP '"org\.mpris\.MediaPlayer2\.\K[^"]+' | head -1)

if [ -z "$PLAYER" ]; then
    echo "STATUS=None" > "$OUTPUT"
    exit 0
fi

DEST="org.mpris.MediaPlayer2.$PLAYER"

# Get PlaybackStatus
STATUS=$(dbus-send --print-reply --dest="$DEST" /org/mpris/MediaPlayer2 \
    org.freedesktop.DBus.Properties.Get \
    string:'org.mpris.MediaPlayer2.Player' string:'PlaybackStatus' 2>/dev/null \
    | grep 'variant.*string' | sed 's/.*string "\(.*\)"/\1/')

# Get Metadata
META=$(dbus-send --print-reply --dest="$DEST" /org/mpris/MediaPlayer2 \
    org.freedesktop.DBus.Properties.Get \
    string:'org.mpris.MediaPlayer2.Player' string:'Metadata' 2>/dev/null)

# Extract title: find xesam:title, then get the next string value
TITLE=$(echo "$META" | awk '/xesam:title/{found=1} found && /variant.*string/{gsub(/.*string "|"$/,"",$0); print; exit}')
TITLE=$(echo "$TITLE" | sed 's/ - YouTube$//')

# Extract artist: find xesam:artist, skip the key line, get the string value in the array
ARTIST=$(echo "$META" | grep -A4 '"xesam:artist"' | grep -v 'xesam:artist' | grep 'string "' | head -1 | sed 's/.*string "\(.*\)"/\1/')

{
    echo "STATUS=${STATUS:-None}"
    echo "TITLE=${TITLE:-}"
    echo "ARTIST=${ARTIST:-}"
    echo "PLAYER=$PLAYER"
} > "$OUTPUT"
