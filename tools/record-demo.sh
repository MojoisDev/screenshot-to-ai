#!/usr/bin/env bash
#
# record-demo.sh — MAINTAINER tool to record the Screenshot to AI demo and
# produce an optimized GIF for the README. This is NOT shipped to end users and
# is NOT used by install.sh.
#
# Usage:
#   tools/record-demo.sh check
#   tools/record-demo.sh record  [--fps N] [--width PX] [--output PATH] [--dir DIR]
#   tools/record-demo.sh convert <video> [--fps N] [--width PX] [--output PATH]
#
# 'record' drives Spectacle's screen recording over D-Bus (start, then ENTER to
# stop), waits for the saved video in Spectacle's video folder (default ~/Videos,
# override with --dir), and converts it. If your session can't record, record
# however you like and use 'convert <video>'.
#
# Defaults: 12 fps, 960px wide, output docs/demo.gif. Warns if the GIF exceeds 8 MB.
set -u

DEFAULT_FPS=12
DEFAULT_WIDTH=960
DEFAULT_OUTPUT="docs/demo.gif"
MAX_MB=8

FPS="$DEFAULT_FPS"
WIDTH="$DEFAULT_WIDTH"
OUTPUT="$DEFAULT_OUTPUT"
WATCH_DIR=""

err()  { echo "record-demo: $*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

parse_opts() {
  # Parse --fps/--width/--output/--dir from "$@"; ignores positionals.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --fps)    FPS="$2"; shift 2 ;;
      --width)  WIDTH="$2"; shift 2 ;;
      --output) OUTPUT="$2"; shift 2 ;;
      --dir)    WATCH_DIR="$2"; shift 2 ;;
      *)        shift ;;
    esac
  done
}

check_deps() {
  # Reports tool status. Returns non-zero if a REQUIRED tool (ffmpeg, spectacle) is missing.
  local missing=0
  if have spectacle; then
    echo "spectacle: present (needed for 'record')"
  else
    echo "spectacle: MISSING — install your distro's spectacle package (needed for 'record')"
    missing=1
  fi
  if have ffmpeg; then
    echo "ffmpeg: present"
  else
    echo "ffmpeg: MISSING — sudo apt install ffmpeg"
    missing=1
  fi
  if have busctl || have dbus-send; then
    echo "dbus client: present (needed to start/stop 'record')"
  else
    echo "dbus client: MISSING — install systemd (busctl) or dbus (dbus-send) for 'record'"
    missing=1
  fi
  if have gifski; then
    echo "gifski: present (will be used for higher-quality GIF)"
  else
    echo "gifski: optional, not found — 'cargo install gifski' or https://gif.ski for better quality"
  fi
  return "$missing"
}

spectacle_video_dir() {
  # Spectacle's configured recording folder; defaults to ~/Videos.
  local dir=""
  if have kreadconfig6; then
    dir="$(kreadconfig6 --file spectaclerc --group VideoSave --key videoSaveLocation 2>/dev/null)"
  fi
  dir="${dir#file://}"
  [ -n "$dir" ] || dir="$HOME/Videos"
  printf '%s' "$dir"
}

newest_video() {
  # newest_video <dir> — print the most-recently-modified video file, or nothing.
  local dir="$1"
  ls -t "$dir"/*.webm "$dir"/*.mp4 "$dir"/*.mkv 2>/dev/null | head -1
}

spectacle_record_toggle() {
  # Start (first call) or stop (second call) a Spectacle screen recording.
  if have busctl; then
    busctl --user call org.kde.Spectacle / org.kde.Spectacle RecordScreen i 1 >/dev/null 2>&1
  elif have dbus-send; then
    dbus-send --session --dest=org.kde.Spectacle / org.kde.Spectacle.RecordScreen int32:1 >/dev/null 2>&1
  else
    return 127
  fi
}

report_size() {
  # report_size <file> — print size and warn if over MAX_MB.
  local f="$1" bytes mb
  bytes="$(wc -c < "$f")"
  mb=$(( bytes / 1024 / 1024 ))
  echo "Wrote $f (${bytes} bytes, ~${mb} MB)."
  if [ "$bytes" -gt $(( MAX_MB * 1024 * 1024 )) ]; then
    echo "WARNING: GIF is over ${MAX_MB} MB; GitHub may not inline it." >&2
    echo "         Re-run with a lower --fps (e.g. 10) or smaller --width (e.g. 800)." >&2
  fi
}

convert_video() {
  # convert_video <video> — produce an optimized GIF at $OUTPUT using $FPS/$WIDTH.
  local video="$1"
  if [ ! -s "$video" ]; then
    err "video file not found or empty: $video"
    return 1
  fi
  if ! have ffmpeg; then
    err "ffmpeg is required. Install: sudo apt install ffmpeg"
    return 1
  fi
  mkdir -p "$(dirname "$OUTPUT")"

  if have gifski; then
    echo "Converting with gifski (high quality)..."
    local framedir
    framedir="$(mktemp -d)" || return 1
    if ! ffmpeg -y -i "$video" -vf "fps=$FPS,scale=$WIDTH:-1:flags=lanczos" "$framedir/frame%05d.png" >/dev/null 2>&1; then
      err "ffmpeg frame extraction failed."
      rm -rf "$framedir"
      return 1
    fi
    if ! gifski --fps "$FPS" --width "$WIDTH" -o "$OUTPUT" "$framedir"/frame*.png; then
      err "gifski conversion failed."
      rm -rf "$framedir"
      return 1
    fi
    rm -rf "$framedir"
  else
    echo "Converting with ffmpeg (palettegen/paletteuse)..."
    local palette
    palette="$(mktemp --suffix=.png)" || return 1
    if ! ffmpeg -y -i "$video" \
        -vf "fps=$FPS,scale=$WIDTH:-1:flags=lanczos,palettegen=stats_mode=diff" \
        "$palette" >/dev/null 2>&1; then
      err "ffmpeg palettegen failed."
      rm -f "$palette"
      return 1
    fi
    if ! ffmpeg -y -i "$video" -i "$palette" \
        -lavfi "fps=$FPS,scale=$WIDTH:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
        "$OUTPUT" >/dev/null 2>&1; then
      err "ffmpeg paletteuse failed."
      rm -f "$palette"
      return 1
    fi
    rm -f "$palette"
  fi

  report_size "$OUTPUT"
}

wait_for_new_video() {
  # wait_for_new_video <dir> <baseline> — print a new, finished video path, or nothing.
  # Polls up to ~30s for a video newer than <baseline> whose size has stabilized.
  local dir="$1" baseline="$2"
  local video="" tries=0 last_size=-1 size
  while [ "$tries" -lt 30 ]; do
    sleep 1
    video="$(newest_video "$dir")"
    if [ -n "$video" ] && [ "$video" != "$baseline" ] && [ -s "$video" ]; then
      size="$(wc -c < "$video")"
      if [ "$size" = "$last_size" ]; then
        printf '%s' "$video"
        return 0
      fi
      last_size="$size"
    fi
    tries=$(( tries + 1 ))
  done
  return 1
}

record_demo() {
  # Drive Spectacle's screen recording over D-Bus, then convert the saved video.
  if ! have spectacle; then
    err "spectacle is required for 'record'. Use 'convert <video>' if you recorded another way."
    return 1
  fi
  if ! have ffmpeg; then
    err "ffmpeg is required. Install: sudo apt install ffmpeg"
    return 1
  fi
  if ! have busctl && ! have dbus-send; then
    err "need a D-Bus client (busctl or dbus-send) to start/stop recording."
    return 1
  fi

  local viddir baseline
  viddir="${WATCH_DIR:-$(spectacle_video_dir)}"
  mkdir -p "$viddir"
  baseline="$(newest_video "$viddir")"

  echo "Starting Spectacle screen recording (saves to: $viddir)"
  if ! spectacle_record_toggle; then
    err "could not start recording via D-Bus (is Spectacle installed and the session KDE?)."
    return 1
  fi
  echo
  echo "RECORDING. Perform the demo now:"
  echo "  hotkey -> drag a box -> switch to the AI page -> Ctrl+V -> type a question -> Enter"
  echo
  printf "When the demo is done, press ENTER here to stop... "
  read -r _ || true

  spectacle_record_toggle
  echo "Stopping; waiting for the saved video..."

  local video
  if ! video="$(wait_for_new_video "$viddir" "$baseline")" || [ -z "$video" ]; then
    err "no new recording appeared in $viddir."
    err "This session may not support screen recording, or Spectacle saved elsewhere."
    err "Record manually and run: tools/record-demo.sh convert <file>"
    return 1
  fi
  echo "Recording saved: $video"

  convert_video "$video"
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    check)
      check_deps
      ;;
    record)
      parse_opts "$@"
      record_demo
      ;;
    convert)
      local video="${1:-}"
      if [ -z "$video" ]; then
        err "convert needs a video file: tools/record-demo.sh convert <video>"
        exit 1
      fi
      shift
      parse_opts "$@"
      convert_video "$video"
      ;;
    ""|-h|--help|help)
      usage
      ;;
    *)
      err "unknown command: $cmd"
      usage
      exit 1
      ;;
  esac
}

# Run main only when executed directly (not when sourced by tests).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
