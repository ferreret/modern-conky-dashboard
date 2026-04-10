#!/bin/bash
# Extract pending topics table from Obsidian Inicio.md
VAULT="/home/nicolas/NickClawVaultMain"
SRC="$VAULT/00_Dashboard/Inicio.md"
CACHE="/tmp/conky-pending.txt"

if [ ! -f "$SRC" ]; then echo "NO_FILE" > "$CACHE"; exit 0; fi

# Extract table rows from "## Temas pendientes" section
sed -n '/^## Temas pendientes$/,/^---$/p' "$SRC" \
    | grep -E '^\|[[:space:]]*[0-9]' \
    | while IFS='|' read -r _ num tema tipo estado _; do
        num=$(echo "$num" | xargs)
        tema=$(echo "$tema" | xargs | sed 's/—/-/g' | cut -c1-45)
        tipo=$(echo "$tipo" | xargs)
        estado=$(echo "$estado" | xargs)
        echo "${num}|${tema}|${tipo}|${estado}"
    done > "$CACHE"

[ ! -s "$CACHE" ] && echo "NO_ITEMS" > "$CACHE"
