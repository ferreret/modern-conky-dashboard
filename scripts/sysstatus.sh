#!/bin/bash
# System status: failed units, recent journal errors, reboot-required, docker
# Output: /tmp/conky-sysstatus.txt (KV format)
set -u
CACHE="/tmp/conky-sysstatus.txt"

failed=$(systemctl --failed --no-legend --no-pager 2>/dev/null | wc -l)
failed_user=$(systemctl --user --failed --no-legend --no-pager 2>/dev/null | wc -l)

jerr=$(journalctl -p 3 -S "1 hour ago" --no-pager -q 2>/dev/null | wc -l)

reboot=0
[ -f /var/run/reboot-required ] && reboot=1

d_total=0; d_up=0; d_down=0; d_unhealthy=0; d_avail=0
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    d_avail=1
    mapfile -t lines < <(docker ps -a --format '{{.Status}}' 2>/dev/null)
    d_total=${#lines[@]}
    for l in "${lines[@]}"; do
        case "$l" in
            Up*unhealthy*) d_unhealthy=$((d_unhealthy+1)); d_up=$((d_up+1)) ;;
            Up*)           d_up=$((d_up+1)) ;;
            *)             d_down=$((d_down+1)) ;;
        esac
    done
fi

{
    echo "FAILED=$failed"
    echo "FAILED_USER=$failed_user"
    echo "JOURNAL_ERR=$jerr"
    echo "REBOOT=$reboot"
    echo "DOCKER_AVAIL=$d_avail"
    echo "DOCKER_TOTAL=$d_total"
    echo "DOCKER_UP=$d_up"
    echo "DOCKER_DOWN=$d_down"
    echo "DOCKER_UNHEALTHY=$d_unhealthy"
} > "$CACHE"
