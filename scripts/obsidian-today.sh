#!/bin/bash
# Extract today's tasks from Obsidian Inicio.md
VAULT="/home/nicolas/NickClawVaultMain"
SRC="$VAULT/00_Dashboard/Inicio.md"
CACHE="/tmp/conky-today.txt"

if [ ! -f "$SRC" ]; then echo "NO_FILE" > "$CACHE"; exit 0; fi

# Extract lines between "## Hoy" and next "##" or ">"
sed -n '/^## Hoy$/,/^>/{/^>/d;p}' "$SRC" \
    | grep '^- \[' \
    | sed 's/\*\*//g; s/\[\[[^]]*|\([^]]*\)\]\]/\1/g; s/\[\[\([^]]*\)\]\]/\1/g; s/—/-/g' \
    | head -6 > "$CACHE"

[ ! -s "$CACHE" ] && echo "NO_TASKS" > "$CACHE"
