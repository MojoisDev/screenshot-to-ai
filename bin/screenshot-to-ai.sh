#!/usr/bin/env bash
#
# screenshot-to-ai.sh — "Circle to Search" for the Linux desktop.
# Capture a screen region to the clipboard and open your chosen AI page.
set -u

CONFIG_FILE="${SCREENSHOT_TO_AI_CONFIG:-$HOME/.config/screenshot-to-ai/config}"

load_config() {
  # Defaults.
  AI_URL="https://www.google.com/search?udm=50"
  CAPTURE_MODE="region"
  BACKEND=""
  CONFIG_FILE="${SCREENSHOT_TO_AI_CONFIG:-$HOME/.config/screenshot-to-ai/config}"
  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
  fi
}

detect_desktop() {
  # Explicit backend override wins.
  case "${BACKEND:-}" in
    spectacle) echo "kde"; return ;;
    gnome-screenshot) echo "gnome"; return ;;
  esac
  case "${XDG_CURRENT_DESKTOP:-}" in
    *KDE*) echo "kde" ;;
    *GNOME*) echo "gnome" ;;
    *) echo "unknown" ;;
  esac
}

build_capture_cmd() {
  # build_capture_cmd <kde|gnome> <region|fullscreen|window>
  local desktop="$1" mode="$2"
  case "$desktop" in
    kde)
      case "$mode" in
        region)     echo "spectacle --region --background --nonotify --copy-image" ;;
        fullscreen) echo "spectacle --fullscreen --background --nonotify --copy-image" ;;
        window)     echo "spectacle --activewindow --background --nonotify --copy-image" ;;
      esac
      ;;
    gnome)
      case "$mode" in
        region)     echo "gnome-screenshot --area --clipboard" ;;
        fullscreen) echo "gnome-screenshot --clipboard" ;;
        window)     echo "gnome-screenshot --window --clipboard" ;;
      esac
      ;;
  esac
}

run() {
  # Execute a command string, or echo it in dry-run mode.
  if [ -n "${DRY_RUN:-}" ]; then echo "RUN: $1"; else eval "$1"; fi
}

notify() {
  if [ -n "${DRY_RUN:-}" ]; then
    echo "NOTIFY: $1"
  else
    notify-send "Screenshot to AI" "$1" >/dev/null 2>&1 || true
  fi
}

open_url() {
  if [ -n "${DRY_RUN:-}" ]; then
    echo "OPEN: $1"
  else
    setsid xdg-open "$1" >/dev/null 2>&1 &
  fi
}

backend_available() {
  # backend_available "<command string>" — true if the first word (the binary) is on PATH.
  command -v "${1%% *}" >/dev/null 2>&1
}

main() {
  load_config
  local desktop cmd bin
  desktop="$(detect_desktop)"
  if [ "$desktop" = "unknown" ]; then
    notify "Unsupported desktop — see the README for manual setup."
    echo "Screenshot to AI: Unsupported desktop." >&2
    exit 1
  fi
  cmd="$(build_capture_cmd "$desktop" "$CAPTURE_MODE")"
  if [ -z "$cmd" ]; then
    notify "Unknown capture mode: $CAPTURE_MODE"
    echo "Screenshot to AI: Unknown capture mode: $CAPTURE_MODE" >&2
    exit 1
  fi
  bin="${cmd%% *}"
  # Verify the capture tool is installed (skipped in dry-run, which only simulates).
  if [ -z "${DRY_RUN:-}" ] && ! backend_available "$cmd"; then
    notify "Capture tool '$bin' not found — please install it."
    echo "Screenshot to AI: '$bin' not found. On Debian/Ubuntu: sudo apt install $bin" >&2
    exit 1
  fi
  # Capture; if it fails, do NOT claim success or open the browser.
  if ! run "$cmd"; then
    notify "Screenshot capture failed."
    echo "Screenshot to AI: capture failed: $cmd" >&2
    exit 1
  fi
  notify "Captured — opening AI"
  open_url "$AI_URL"
}

# Run main only when executed directly (not when sourced by tests).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
