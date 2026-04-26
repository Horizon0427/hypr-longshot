#!/bin/bash
# longshot.sh - Long screenshot tool (Wayland/Hyprland)
# Requires: slurp, wf-recorder, hyprctl, notify-send, python venv

set -u
trap 'echo -e "\n\033[1;31m[INFO] Caught interrupt signal, cleaning up...\033[0m"; cleanup_overlay; safe_kill -SIGINT "${REC_PID:-}"; cleanup_temp; rm -f "$PID_FILE"; pkill -RTMIN+8 waybar 2>/dev/null; exit 1' SIGINT SIGTERM

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_EXEC="$SCRIPT_DIR/.venv/bin/python"
OVERLAY_BIN="$SCRIPT_DIR/longshot_overlay"
TEMP_VIDEO="/tmp/longshot_temp_$$.mp4"
WF_LOG="/tmp/longshot_wf_$$.log"
OUTPUT_IMG="$HOME/Pictures/longshots/longshot_$(date +%s).png"
PID_FILE="/tmp/longshot_recording.pid"
PADDING=10
MAX_WAIT_SEC=3600

die() {
  notify-send -u critical "Longshot" "$1" 2>/dev/null
  echo -e "\033[1;31m[ERROR] $1\033[0m" >&2
  exit 1
}

is_positive_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_nonneg_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

read_pid_file() {
  [ -f "$PID_FILE" ] || return 1
  local pid
  pid=$(cat "$PID_FILE" 2>/dev/null)
  if ! [[ "$pid" =~ ^[1-9][0-9]*$ ]]; then
    echo "[WARN] PID file contains invalid content, removing." >&2
    rm -f "$PID_FILE"
    return 1
  fi
  echo "$pid"
}

safe_kill() {
  local sig="$1" pid="$2"
  if kill -0 "$pid" 2>/dev/null; then
    kill "$sig" "$pid" 2>/dev/null
  fi
}

cleanup_overlay() {
  pkill -9 -f "$OVERLAY_BIN" 2>/dev/null || true
}

cleanup_temp() {
  rm -f "$TEMP_VIDEO" "$WF_LOG"
}

[ -x "$OVERLAY_BIN" ] || die "overlay binary not found or not executable: $OVERLAY_BIN"
[ -x "$PYTHON_EXEC" ] || die "python not found: $PYTHON_EXEC"
command -v slurp >/dev/null 2>&1 || die "slurp not found"
command -v wf-recorder >/dev/null 2>&1 || die "wf-recorder not found"
command -v hyprctl >/dev/null 2>&1 || die "hyprctl not found"

if [[ ! "${WAYLAND_DISPLAY:-}" =~ ^wayland-[0-9]+$ ]]; then
  die "WAYLAND_DISPLAY is unset or has unexpected format: '${WAYLAND_DISPLAY:-}'"
fi

mkdir -p "$HOME/Pictures/longshots" || die "Cannot create output directory"

if [ "${1:-}" = "cancel" ]; then
  REC_PID=$(read_pid_file) || {
    echo "No active recording found."
    exit 0
  }
  safe_kill -SIGINT "$REC_PID"
  local_wait=0
  while kill -0 "$REC_PID" 2>/dev/null && [ $local_wait -lt 5 ]; do
    sleep 0.2
    local_wait=$((local_wait + 1))
  done
  cleanup_overlay
  rm -f "$PID_FILE"
  cleanup_temp
  pkill -RTMIN+8 waybar 2>/dev/null
  notify-send -u normal "Longshot" "Canceled."
  exit 0
fi

if REC_PID=$(read_pid_file); then
  if kill -0 "$REC_PID" 2>/dev/null; then
    safe_kill -SIGINT "$REC_PID"
    exit 0
  else
    rm -f "$PID_FILE"
  fi
fi

if [ -t 0 ]; then
  echo -e "\033[1;36m Please select area for longshot. \033[0m"
fi

GEOMETRY=$(slurp 2>/dev/null) || exit 0

if ! [[ "$GEOMETRY" =~ ^([0-9]+),([0-9]+)\ ([0-9]+)x([0-9]+)$ ]]; then
  die "Unexpected geometry format from slurp: '$GEOMETRY'"
fi
X="${BASH_REMATCH[1]}"
Y="${BASH_REMATCH[2]}"
W="${BASH_REMATCH[3]}"
H="${BASH_REMATCH[4]}"

if ! is_positive_int "$W" || ! is_positive_int "$H"; then
  die "Invalid selection: width/height must be positive (got W=$W H=$H)"
fi

oX=$((X > PADDING ? X - PADDING : 0))
oY=$((Y > PADDING ? Y - PADDING : 0))
oW=$((W + PADDING * 2))
oH=$((H + PADDING * 2))

wf-recorder -g "$GEOMETRY" -f "$TEMP_VIDEO" >"$WF_LOG" 2>&1 &
REC_PID=$!
echo "$REC_PID" >"$PID_FILE"

hyprctl dispatch exec \
  "[move $oX $oY; size $oW $oH] env XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=${WAYLAND_DISPLAY} ${OVERLAY_BIN} $oW $oH" \
  >/dev/null 2>&1
sleep 0.3

pkill -RTMIN+8 waybar 2>/dev/null
notify-send -t 3000 "🔴 Longshot starts." \
  "Please scroll the page downward slowly.\nClick button when done."

do_stitch() {
  local out_img="$HOME/Pictures/longshots/longshot_$(date +%s).png"

  cleanup_overlay
  rm -f "$PID_FILE"
  pkill -RTMIN+8 waybar 2>/dev/null

  if [ ! -f "$TEMP_VIDEO" ]; then
    notify-send -u critical "Longshot" "Temp video missing, stitching aborted."
    return 1
  fi

  "$PYTHON_EXEC" "$SCRIPT_DIR/stitcher.py" "$TEMP_VIDEO" "$out_img"

  if [ -f "$out_img" ]; then
    notify-send -i "$out_img" "✅ Longshot generated." "path: $out_img"
    [ -t 1 ] && echo -e "\033[1;32m Longshot saved: $out_img\033[0m"
    cleanup_temp
  else
    notify-send -u critical "Longshot error" "Failed to generate longshot"
    [ -t 1 ] && echo -e "\033[1;31m[ERROR] Failed to generate longshot.\033[0m" >&2
    return 1
  fi
}

if [ -t 0 ]; then
  echo -e "\n\033[1;41;37m 🔴 REC \033[0m \033[1;31m Recording: [ $GEOMETRY ]\033[0m"
  echo -e "\033[1;33m Scroll the page downward slowly, press any key when done.\033[0m"

  while kill -0 "$REC_PID" 2>/dev/null; do
    if read -t 0.2 -n 1 -s -r; then
      echo -e "\033[1;32m Stop signal detected.\033[0m"
      safe_kill -SIGINT "$REC_PID"
      break
    fi
  done

  wait "$REC_PID" 2>/dev/null
  echo -e "\033[1;34m Stitching... Please wait...\033[0m"
  do_stitch

else
  (
    waited=0
    while kill -0 "$REC_PID" 2>/dev/null; do
      sleep 0.5
      waited=$((waited + 1))
      if [ $((waited / 2)) -ge $MAX_WAIT_SEC ]; then
        echo "[WARN] Recording exceeded max wait time, forcing stop." >&2
        safe_kill -SIGINT "$REC_PID"
        break
      fi
    done
    wait "$REC_PID" 2>/dev/null
    notify-send -t 3000 "Stitching..." "OpenCV is processing..."
    do_stitch
  ) &
  disown
  exit 0
fi
