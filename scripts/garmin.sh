#!/bin/bash
# Extract Garmin vital signs from Obsidian vault
VAULT="/home/nicolas/NickClawVaultMain"
SRC="$VAULT/00_Dashboard/Inicio.md"
CACHE="/tmp/conky-garmin.txt"

if [ ! -f "$SRC" ]; then echo "NO_FILE" > "$CACHE"; exit 0; fi

# Parse "Pulso vital" table from Inicio.md
# Format: | BB | Sueño | FC | Estrés | Pasos |
ROW=$(grep -A2 "Body Battery" "$SRC" | tail -1)

if [ -z "$ROW" ]; then echo "NO_DATA" > "$CACHE"; exit 0; fi

BB=$(echo "$ROW" | awk -F'|' '{print $2}' | grep -oP '^\s*\K\d+')
BB_PEAK=$(echo "$ROW" | awk -F'|' '{print $2}' | grep -oP 'pico \K\d+')
SLEEP_H=$(echo "$ROW" | awk -F'|' '{print $3}' | grep -oP -m1 '[\d.]+(?=\s*h)' | head -1)
SLEEP_SCORE=$(echo "$ROW" | awk -F'|' '{print $3}' | grep -oP 'score \K\d+')
HR=$(echo "$ROW" | awk -F'|' '{print $4}' | grep -oP -m1 '\d+')
STRESS=$(echo "$ROW" | awk -F'|' '{print $5}' | grep -oP '^\s*\K\d+')
STRESS_TXT=$(echo "$ROW" | awk -F'|' '{print $5}' | grep -oP '\(\K[^)]+')
STEPS=$(echo "$ROW" | awk -F'|' '{print $6}' | grep -oP -m1 '[\d.]+' | head -1)

{
    echo "BB=${BB:-0}"
    echo "BB_PEAK=${BB_PEAK:-0}"
    echo "SLEEP=${SLEEP_H:-0}"
    echo "SLEEP_SCORE=${SLEEP_SCORE:-0}"
    echo "HR=${HR:-0}"
    echo "STRESS=${STRESS:-0}"
    echo "STRESS_TXT=${STRESS_TXT:-unknown}"
    echo "STEPS=${STEPS:-0}"
} > "$CACHE"
