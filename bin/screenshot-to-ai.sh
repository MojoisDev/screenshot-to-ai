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

# Run main only when executed directly (not when sourced by tests).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
