#!/usr/bin/env bash
#
# record-demo.sh — MAINTAINER tool to record the Screenshot to AI demo and
# produce an optimized GIF for the README. This is NOT shipped to end users and
# is NOT used by install.sh.
#
# Usage:
#   tools/record-demo.sh check
#   tools/record-demo.sh record  [--fps N] [--width PX] [--output PATH] [--keep-video]
#   tools/record-demo.sh convert <video> [--fps N] [--width PX] [--output PATH]
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
KEEP_VIDEO=""

err()  { echo "record-demo: $*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

parse_opts() {
  # Parse --fps/--width/--output/--keep-video from "$@"; ignores positionals.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --fps)        FPS="$2"; shift 2 ;;
      --width)      WIDTH="$2"; shift 2 ;;
      --output)     OUTPUT="$2"; shift 2 ;;
      --keep-video) KEEP_VIDEO=1; shift ;;
      *)            shift ;;
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
  if have gifski; then
    echo "gifski: present (will be used for higher-quality GIF)"
  else
    echo "gifski: optional, not found — 'cargo install gifski' or https://gif.ski for better quality"
  fi
  return "$missing"
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

record_demo() {
  # Record the full screen with spectacle, then convert to GIF.
  if ! have spectacle; then
    err "spectacle is required for 'record'. Use 'convert <video>' if you recorded another way."
    return 1
  fi
  if ! have ffmpeg; then
    err "ffmpeg is required. Install: sudo apt install ffmpeg"
    return 1
  fi
  local tmpvid
  tmpvid="$(mktemp -u --suffix=.webm)" || return 1

  echo "Starting full-screen recording with Spectacle."
  echo
  echo "  1. Perform the demo now: trigger the hotkey, drag a box, switch to the"
  echo "     AI page, press Ctrl+V, type a question, hit Enter."
  echo "  2. When done, STOP the recording using Spectacle's stop control"
  echo "     (system-tray icon / notification, or the 'Stop Screen Recording' shortcut)."
  echo
  echo "Waiting for the recording to finish..."

  # In background record mode, spectacle records until the user stops it, then
  # writes the file and exits. We block on it.
  spectacle --record screen --background --nonotify --output "$tmpvid" >/dev/null 2>&1
  if [ ! -s "$tmpvid" ]; then
    err "no video was produced at $tmpvid."
    err "If Spectacle returned immediately, record manually and run: tools/record-demo.sh convert <file>"
    return 1
  fi
  echo "Recording captured: $tmpvid"

  convert_video "$tmpvid" || { [ -n "$KEEP_VIDEO" ] || rm -f "$tmpvid"; return 1; }

  if [ -n "$KEEP_VIDEO" ]; then
    echo "Kept source video: $tmpvid"
  else
    rm -f "$tmpvid"
  fi
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

main "$@"
