#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_EXEC="$SCRIPT_DIR/.venv/bin/python"
OVERLAY_BIN="$SCRIPT_DIR/longshot_overlay"
TEMP_VIDEO="/tmp/longshot_temp.mp4"
OUTPUT_IMG="$HOME/Pictures/longshots/longshot_$(date +%s).png"
PID_FILE="/tmp/longshot_recording.pid"

mkdir -p "$HOME/Pictures/longshots"

if [ "$1" == "cancel" ]; then
  if [ -f "$PID_FILE" ]; then
    REC_PID=$(cat "$PID_FILE")
    kill -SIGINT "$REC_PID" 2>/dev/null
    pkill -f "$OVERLAY_BIN" 2>/dev/null
    rm -f "$PID_FILE" "$TEMP_VIDEO"

    pkill -RTMIN+8 waybar
    notify-send -u normal "Longshot" "Canceled."
  fi
  exit 0
fi

if [ -f "$PID_FILE" ]; then
  REC_PID=$(cat "$PID_FILE")
  if kill -0 "$REC_PID" 2>/dev/null; then
    kill -SIGINT "$REC_PID" 2>/dev/null
    exit 0
  else
    rm -f "$PID_FILE"
  fi
fi

if [ -t 0 ]; then
  echo -e "\033[1;36m Please select area for longshot. \033[0m"
fi

GEOMETRY=$(slurp) || exit 0

FORMATTED_GEOM=$(echo "$GEOMETRY" | tr ',x' ' ')
read -r X Y W H <<<"$FORMATTED_GEOM"

PADDING=10
oX=$((X - PADDING))
oY=$((Y - PADDING))
oW=$((W + PADDING * 2))
oH=$((H + PADDING * 2))

wf-recorder -g "$GEOMETRY" -f "$TEMP_VIDEO" >/tmp/wf_log.txt 2>&1 &
REC_PID=$!
echo "$REC_PID" >"$PID_FILE"

hyprctl dispatch exec "[move $oX $oY; size $oW $oH] env XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=$WAYLAND_DISPLAY '$OVERLAY_BIN'" >/dev/null 2>&1

pkill -RTMIN+8 waybar
notify-send -t 3000 "🔴 Longshot starts." "Please scroll the page downward slowly. \n Click button when it's done."

if [ -t 0 ]; then
  echo -e "\n\033[1;41;37m 🔴 REC \033[0m \033[1;31m Recording: [ $GEOMETRY ]\033[0m"
  echo -e "\033[1;33m Please scroll the page downward slowly, press any key if done.\033[0m"

  while kill -0 "$REC_PID" 2>/dev/null; do
    if read -t 0.2 -n 1 -s -r; then
      echo -e "\033[1;32m Stop signal detected.\033[0m"
      kill -SIGINT "$REC_PID" 2>/dev/null
      break
    fi
  done

  wait "$REC_PID" 2>/dev/null

  pkill -f "$OVERLAY_BIN" 2>/dev/null
  rm -f "$PID_FILE"
  pkill -RTMIN+8 waybar

  if [ ! -f "$TEMP_VIDEO" ]; then
    exit 0
  fi

  echo -e "\033[1;34m Stitching...Please wait...\033[0m"
  "$PYTHON_EXEC" "$SCRIPT_DIR/stitcher.py" "$TEMP_VIDEO" "$OUTPUT_IMG"

  if [ -f "$OUTPUT_IMG" ]; then
    notify-send -i "$OUTPUT_IMG" " Longshot generated." "path: $OUTPUT_IMG"
    echo -e "\033[1;32m longshot successfully generated. path: $OUTPUT_IMG\033[0m"
    rm -f "$TEMP_VIDEO"
  else
    notify-send -u critical " error" "Failed to generate longshot"
    echo -e "\033[1;31m error: failed to generate longshot.\033[0m"
  fi

else
  (
    while kill -0 "$REC_PID" 2>/dev/null; do
      sleep 0.5
    done

    pkill -f "$OVERLAY_BIN" 2>/dev/null
    rm -f "$PID_FILE"
    pkill -RTMIN+8 waybar

    if [ ! -f "$TEMP_VIDEO" ]; then
      exit 0
    fi

    notify-send -t 3000 " Stitching...Please wait..." "OpenCV is processing..."

    "$PYTHON_EXEC" "$SCRIPT_DIR/stitcher.py" "$TEMP_VIDEO" "$OUTPUT_IMG"

    if [ -f "$OUTPUT_IMG" ]; then
      notify-send -i "$OUTPUT_IMG" " Longshot generated." "path: $OUTPUT_IMG"
      rm -f "$TEMP_VIDEO"
    else
      notify-send -u critical " error" "Failed to generate longshot"
    fi
  ) &
  disown
  exit 0
fi
