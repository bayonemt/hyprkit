#!/bin/bash
# hyprrec - screen recorder + instant replay, driven by gpu-screen-recorder.
#
#   hyprrec.sh replay start|stop|toggle     replay buffer (always-on, saves the last N seconds on demand)
#   hyprrec.sh clip [seconds]               save the replay buffer (default: whole buffer); 10, 30, 60 also work
#   hyprrec.sh record toggle|start|stop     record the focused monitor (inside the replay process when it runs)
#   hyprrec.sh record region                pick an area with slurp and record it
#   hyprrec.sh status                       JSON with the current state (used by the panel)
#   hyprrec.sh open                         open the videos folder
#
# Config (optional): ~/.config/hyprrec/config, a bash file. Defaults below.
set -u
CONFIG="$HOME/.config/hyprrec/config"
VIDEOS_DIR="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/hyprrec"
MONITOR=""                   # empty = monitor focused when the replay starts
FPS=60
REPLAY_SECONDS=30            # size of the replay buffer
AUDIO="default_output|default_input"   # "|" merges into one track; use one -a per source for separate tracks
QUALITY=very_high            # medium | high | very_high | ultra
CODEC=""                     # empty = let gsr pick (h264); or h264 | hevc | av1
REPLAY_AUTOSTART=yes
[ -f "$CONFIG" ] && . "$CONFIG"

STATE="${XDG_RUNTIME_DIR:-/tmp}/hyprrec"
mkdir -p "$STATE" "$VIDEOS_DIR/Replays" "$VIDEOS_DIR/Recordings"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONSAVE="$HERE/on-save.sh"
QS_MAIN="$HERE/../Main.qml"

focused_monitor() { hyprctl -j monitors | python3 -c 'import sys,json;print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))' 2>/dev/null; }
replay_pid()   { [ -f "$STATE/replay.pid" ] && kill -0 "$(cat "$STATE/replay.pid")" 2>/dev/null && cat "$STATE/replay.pid"; }
record_pid()   { [ -f "$STATE/record.pid" ] && kill -0 "$(cat "$STATE/record.pid")" 2>/dev/null && cat "$STATE/record.pid"; }
notify_ui()    { quickshell ipc -p "$QS_MAIN" call hyprrec refresh >/dev/null 2>&1 || true; }
common_args()  { local a=(-f "$FPS" -q "$QUALITY" -c mp4 -cursor yes -sc "$ONSAVE" -a "$AUDIO"); [ -n "$CODEC" ] && a+=(-k "$CODEC"); printf '%s\n' "${a[@]}"; }

replay_start() {
    if replay_pid >/dev/null; then echo "replay already running"; return 0; fi
    local mon="${MONITOR:-$(focused_monitor)}"
    mapfile -t args < <(common_args)
    setsid gpu-screen-recorder -w "$mon" "${args[@]}" -r "$REPLAY_SECONDS" -o "$VIDEOS_DIR/Replays" -ro "$VIDEOS_DIR/Recordings" \
        >"$STATE/replay.log" 2>&1 &
    echo $! > "$STATE/replay.pid"; echo "$mon" > "$STATE/replay.monitor"
    rm -f "$STATE/recording"
    sleep 0.3; notify_ui
}
replay_stop() {
    local p; p=$(replay_pid) || { rm -f "$STATE/replay.pid" "$STATE/recording"; notify_ui; return 0; }
    kill -INT "$p" 2>/dev/null; for i in $(seq 1 40); do kill -0 "$p" 2>/dev/null || break; sleep 0.1; done
    rm -f "$STATE/replay.pid" "$STATE/recording"; notify_ui
}

clip() {
    local p; p=$(replay_pid) || { notify-send -a hyprrec -i camera-video "hyprrec" "Replay is not running"; return 1; }
    case "${1:-}" in
        10) kill -RTMIN+1 "$p";; 30) kill -RTMIN+2 "$p";; 60) kill -RTMIN+3 "$p";; 300) kill -RTMIN+4 "$p";;
        *)  kill -USR1 "$p";;
    esac
}

record_start() {
    if [ -f "$STATE/recording" ]; then echo "already recording"; return 0; fi
    local p; if p=$(replay_pid); then
        kill -RTMIN "$p"                       # regular recording inside the replay process -> -ro dir
        echo "replay:$p" > "$STATE/recording"
    else
        local mon="${MONITOR:-$(focused_monitor)}"
        mapfile -t args < <(common_args)
        setsid gpu-screen-recorder -w "$mon" "${args[@]}" -o "$VIDEOS_DIR/Recordings" >"$STATE/record.log" 2>&1 &
        echo $! > "$STATE/record.pid"; echo "standalone:$!" > "$STATE/recording"
    fi
    date +%s > "$STATE/recording.start"; notify_ui
}
record_region() {
    if [ -f "$STATE/recording" ]; then echo "already recording"; return 0; fi
    local geo; geo=$(slurp -f "%wx%h+%x+%y" 2>/dev/null) || return 1
    mapfile -t args < <(common_args)
    setsid gpu-screen-recorder -w region -region "$geo" "${args[@]}" -o "$VIDEOS_DIR/Recordings" >"$STATE/record.log" 2>&1 &
    echo $! > "$STATE/record.pid"; echo "standalone:$!" > "$STATE/recording"
    date +%s > "$STATE/recording.start"; notify_ui
}
record_stop() {
    [ -f "$STATE/recording" ] || return 0
    local kind; kind=$(cut -d: -f1 "$STATE/recording")
    if [ "$kind" = "replay" ]; then
        local p; p=$(replay_pid) && kill -RTMIN "$p"
    else
        local p; p=$(record_pid) && { kill -INT "$p"; for i in $(seq 1 40); do kill -0 "$p" 2>/dev/null || break; sleep 0.1; done; }
        rm -f "$STATE/record.pid"
    fi
    rm -f "$STATE/recording" "$STATE/recording.start"; notify_ui
}

status() {
    local rp="" rec=0 start=0 last="" mon=""
    rp=$(replay_pid) && mon=$(cat "$STATE/replay.monitor" 2>/dev/null)
    [ -f "$STATE/recording" ] && rec=1 && start=$(cat "$STATE/recording.start" 2>/dev/null || echo 0)
    [ -f "$STATE/last_saved" ] && last=$(cat "$STATE/last_saved")
    printf '{"replay":%s,"recording":%s,"start":%s,"replaySeconds":%s,"monitor":"%s","dir":"%s","last":"%s"}\n' \
        "$([ -n "$rp" ] && echo true || echo false)" "$([ "$rec" = 1 ] && echo true || echo false)" "${start:-0}" "$REPLAY_SECONDS" "$mon" "$VIDEOS_DIR" "${last//\"/\\\"}"
}

case "${1:-}" in
    replay) case "${2:-toggle}" in start) replay_start;; stop) replay_stop;; toggle) replay_pid >/dev/null && replay_stop || replay_start;; esac;;
    clip)   clip "${2:-}";;
    record) case "${2:-toggle}" in start) record_start;; stop) record_stop;; region) record_region;; toggle) [ -f "$STATE/recording" ] && record_stop || record_start;; esac;;
    status) status;;
    open)   xdg-open "$VIDEOS_DIR" >/dev/null 2>&1 &;;
    autostart) [ "$REPLAY_AUTOSTART" = yes ] && replay_start;;
    *) sed -n 2,12p "$0"; exit 1;;
esac
