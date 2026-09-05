#!/bin/bash
# Called by gpu-screen-recorder after a file is saved: $1 = path, $2 = regular|replay|screenshot
STATE="${XDG_RUNTIME_DIR:-/tmp}/hyprrec"; mkdir -p "$STATE"
printf '%s\n' "$1" > "$STATE/last_saved"
name=$(basename "$1")
if [[ "${LANG:-}" == pt* ]]; then
    [ "$2" = replay ] && title="Clipe salvo" || title="Gravação salva"
else
    [ "$2" = replay ] && title="Clip saved" || title="Recording saved"
fi
notify-send -a hyprrec -i camera-video "$title" "$name" >/dev/null 2>&1 || true
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
quickshell ipc -p "$HERE/../Main.qml" call hyprrec refresh >/dev/null 2>&1 || true
