#!/bin/bash
# Git multi-repo status
# Reads repo paths from modern/.gitrepos (one per line, # comments ok)
# Output: /tmp/conky-gitstatus.txt (tab-separated: name\tbranch\tdirty\tahead\tbehind)
set -u
CACHE="/tmp/conky-gitstatus.txt"
LIST="$(dirname "$0")/../.gitrepos"

if [ ! -f "$LIST" ]; then
    echo "NO_LIST" > "$CACHE"; exit 0
fi

: > "$CACHE"
while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    repo="${line%%|*}"
    alias="${line#*|}"
    repo="${repo/#\~/$HOME}"
    [ -d "$repo/.git" ] || continue
    if [ "$alias" = "$line" ]; then name=$(basename "$repo"); else name="$alias"; fi
    branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    dirty=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l)
    ahead=0; behind=0
    ab=$(git -C "$repo" rev-list --left-right --count "@{u}...HEAD" 2>/dev/null)
    if [ -n "$ab" ]; then
        behind=$(echo "$ab" | awk '{print $1}')
        ahead=$(echo "$ab" | awk '{print $2}')
    fi
    printf "%s\t%s\t%s\t%s\t%s\n" "$name" "$branch" "$dirty" "$ahead" "$behind" >> "$CACHE"
done < "$LIST"

[ -s "$CACHE" ] || echo "NO_REPOS" > "$CACHE"
