#!/bin/bash
# Fetch Proxmox node + VMs/LXC + storage via API token
# Output: /tmp/conky-proxmox.txt
set -u
CACHE="/tmp/conky-proxmox.txt"
ENV_FILE="$(dirname "$0")/../.proxmox.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "STATUS=NO_ENV" > "$CACHE"; exit 0
fi
# shellcheck disable=SC1090
. "$ENV_FILE"

: "${PVE_HOST:?}"; : "${PVE_PORT:=8006}"; : "${PVE_TOKEN_ID:?}"; : "${PVE_TOKEN_SECRET:?}"
: "${PVE_INSECURE:=1}"

CURL_OPTS=(-sS --max-time 4 -H "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}")
[ "$PVE_INSECURE" = "1" ] && CURL_OPTS+=(-k)
BASE="https://${PVE_HOST}:${PVE_PORT}/api2/json"

if ! command -v jq >/dev/null 2>&1; then
    echo "STATUS=NO_JQ" > "$CACHE"; exit 0
fi

NODES_JSON=$(curl "${CURL_OPTS[@]}" "$BASE/nodes" 2>/dev/null)
if [ -z "$NODES_JSON" ] || ! echo "$NODES_JSON" | jq -e '.data' >/dev/null 2>&1; then
    echo "STATUS=UNREACHABLE" > "$CACHE"; exit 0
fi

NODE=$(echo "$NODES_JSON" | jq -r '.data[0].node // ""')
if [ -z "$NODE" ]; then echo "STATUS=NO_NODE" > "$CACHE"; exit 0; fi

CPU=$(echo "$NODES_JSON" | jq -r --arg n "$NODE" '.data[] | select(.node==$n) | (.cpu*100|floor)')
MEM_USED=$(echo "$NODES_JSON" | jq -r --arg n "$NODE" '.data[] | select(.node==$n) | .mem')
MEM_TOTAL=$(echo "$NODES_JSON" | jq -r --arg n "$NODE" '.data[] | select(.node==$n) | .maxmem')
DISK_USED=$(echo "$NODES_JSON" | jq -r --arg n "$NODE" '.data[] | select(.node==$n) | .disk')
DISK_TOTAL=$(echo "$NODES_JSON" | jq -r --arg n "$NODE" '.data[] | select(.node==$n) | .maxdisk')
UPTIME=$(echo "$NODES_JSON" | jq -r --arg n "$NODE" '.data[] | select(.node==$n) | .uptime')

MEM_PCT=$(awk -v u="$MEM_USED" -v t="$MEM_TOTAL" 'BEGIN{ if(t>0) printf "%d", u*100/t; else print 0 }')
DISK_PCT=$(awk -v u="$DISK_USED" -v t="$DISK_TOTAL" 'BEGIN{ if(t>0) printf "%d", u*100/t; else print 0 }')

# Format uptime: "12d 4h" or "4h 23m"
DAYS=$(( UPTIME / 86400 ))
HOURS=$(( (UPTIME % 86400) / 3600 ))
MINS=$(( (UPTIME % 3600) / 60 ))
if [ "$DAYS" -gt 0 ]; then UP_STR="${DAYS}d ${HOURS}h"
elif [ "$HOURS" -gt 0 ]; then UP_STR="${HOURS}h ${MINS}m"
else UP_STR="${MINS}m"; fi

# Load average — node status endpoint
STATUS_JSON=$(curl "${CURL_OPTS[@]}" "$BASE/nodes/$NODE/status" 2>/dev/null)
LOAD=$(echo "$STATUS_JSON" | jq -r '.data.loadavg[0] // "0"')

{
    echo "STATUS=OK"
    echo "NODE=$NODE"
    echo "CPU=$CPU"
    echo "MEM=$MEM_PCT"
    echo "DISK=$DISK_PCT"
    echo "UPTIME=$UP_STR"
    echo "LOAD=$LOAD"
} > "$CACHE"

# QEMU VMs
QEMU=$(curl "${CURL_OPTS[@]}" "$BASE/nodes/$NODE/qemu" 2>/dev/null)
echo "$QEMU" | jq -r '.data[]? | "GUEST=" + (.vmid|tostring) + "|qemu|" + .status + "|" + (.name // "vm") + "|" + ((.cpu // 0)*100|floor|tostring) + "|" + (if .maxmem>0 then ((.mem // 0)*100/.maxmem|floor|tostring) else "0" end)' >> "$CACHE" 2>/dev/null

# LXC containers
LXC=$(curl "${CURL_OPTS[@]}" "$BASE/nodes/$NODE/lxc" 2>/dev/null)
echo "$LXC" | jq -r '.data[]? | "GUEST=" + (.vmid|tostring) + "|lxc|" + .status + "|" + (.name // "ct") + "|" + ((.cpu // 0)*100|floor|tostring) + "|" + (if .maxmem>0 then ((.mem // 0)*100/.maxmem|floor|tostring) else "0" end)' >> "$CACHE" 2>/dev/null

# Storages
STOR=$(curl "${CURL_OPTS[@]}" "$BASE/nodes/$NODE/storage" 2>/dev/null)
echo "$STOR" | jq -r '.data[]? | select(.total>0) | "STORE=" + .storage + "|" + ((.used*100/.total)|floor|tostring) + "|" + (.total|tostring)' >> "$CACHE" 2>/dev/null
