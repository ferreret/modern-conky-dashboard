#!/bin/bash
# Count pending inbox captures from Obsidian
VAULT="/home/nicolas/NickClawVaultMain"
SRC="$VAULT/99_Inbox/Capturas.md"
CACHE="/tmp/conky-inbox.txt"

if [ ! -f "$SRC" ]; then echo "0" > "$CACHE"; exit 0; fi

# Count ### headers that are NOT struck through (~~)
TOTAL=$(grep -c "^### " "$SRC")
DONE=$(grep -c "^### ~~" "$SRC")
PENDING=$((TOTAL - DONE))

echo "$PENDING" > "$CACHE"
