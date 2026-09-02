#!/bin/bash
# hyprgrid toggle script.
# Keeps quickshell running as a daemon so the grid opens instantly.
#   toggle.sh           open/close the grid (starts the daemon if needed)
#   toggle.sh --daemon  only start the daemon in the background (for exec-once)
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="$QS_DIR/Main.qml"
# Make Qt resolve icons through the GTK icon theme (gtk-icon-theme-name in ~/.config/gtk-3.0/settings.ini)
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-gtk3}"

is_running() { pgrep -f "quickshell -p ${MAIN}" >/dev/null 2>&1; }

if ! is_running; then
    cd "$QS_DIR" || exit 1
    nohup quickshell -p "$MAIN" --no-duplicate >/tmp/hyprgrid.log 2>&1 &
    disown
    [ "$1" = "--daemon" ] && exit 0
    # wait until the IPC answers, then open
    for i in $(seq 1 60); do
        quickshell ipc -p "$MAIN" call hyprgrid open >/dev/null 2>&1 && exit 0
        sleep 0.05
    done
    exit 1
fi

[ "$1" = "--daemon" ] && exit 0
quickshell ipc -p "$MAIN" call hyprgrid toggle
