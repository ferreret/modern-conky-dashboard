#!/bin/bash
# Fetch calendar events and cache to /tmp/conky-calendar.txt
# Called by conky via ${execi 300 ...} (every 5 minutes)
# Requires: gcalcli (pip install gcalcli)
CACHE="/tmp/conky-calendar.txt"

GCALCLI="$(dirname "$0")/../venv/bin/gcalcli"

if [ ! -x "$GCALCLI" ]; then
    echo "NO_GCALCLI" > "$CACHE"
    exit 0
fi

"$GCALCLI" agenda --nostarted --nodeclined --tsv \
    "$(date '+%Y-%m-%dT%H:%M')" \
    "$(date -d '+2 days' '+%Y-%m-%dT23:59')" 2>/dev/null \
    | tail -n+2 | head -12 > "$CACHE"

# If empty, write marker
[ ! -s "$CACHE" ] && echo "NO_EVENTS" > "$CACHE"
