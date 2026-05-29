#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.." || exit 1
. tests/lib.sh

# Source the engine without running main.
. bin/screenshot-to-ai.sh

# Defaults when no config file exists.
SCREENSHOT_TO_AI_CONFIG="/nonexistent/path/config"
load_config
assert_eq "$AI_URL" "https://www.google.com/search?udm=50" "default AI_URL"
assert_eq "$CAPTURE_MODE" "region" "default CAPTURE_MODE"

# Values from a config file override defaults.
tmp="$(mktemp)"
printf 'AI_URL="https://example.com/"\nCAPTURE_MODE="fullscreen"\n' > "$tmp"
SCREENSHOT_TO_AI_CONFIG="$tmp"
load_config
assert_eq "$AI_URL" "https://example.com/" "config overrides AI_URL"
assert_eq "$CAPTURE_MODE" "fullscreen" "config overrides CAPTURE_MODE"
rm -f "$tmp"

# Desktop detection from XDG_CURRENT_DESKTOP.
BACKEND=""
XDG_CURRENT_DESKTOP="KDE"
assert_eq "$(detect_desktop)" "kde" "detect KDE"
XDG_CURRENT_DESKTOP="ubuntu:GNOME"
assert_eq "$(detect_desktop)" "gnome" "detect GNOME"
XDG_CURRENT_DESKTOP="sway"
assert_eq "$(detect_desktop)" "unknown" "detect unknown"

# Explicit BACKEND overrides detection.
XDG_CURRENT_DESKTOP="sway"
BACKEND="spectacle"
assert_eq "$(detect_desktop)" "kde" "BACKEND=spectacle forces kde"
BACKEND="gnome-screenshot"
assert_eq "$(detect_desktop)" "gnome" "BACKEND=gnome-screenshot forces gnome"
BACKEND=""

# KDE capture commands per mode.
assert_eq "$(build_capture_cmd kde region)" \
  "spectacle --region --background --nonotify --copy-image" "kde region"
assert_eq "$(build_capture_cmd kde fullscreen)" \
  "spectacle --fullscreen --background --nonotify --copy-image" "kde fullscreen"
assert_eq "$(build_capture_cmd kde window)" \
  "spectacle --activewindow --background --nonotify --copy-image" "kde window"

# GNOME capture commands per mode.
assert_eq "$(build_capture_cmd gnome region)" "gnome-screenshot --area --clipboard" "gnome region"
assert_eq "$(build_capture_cmd gnome fullscreen)" "gnome-screenshot --clipboard" "gnome fullscreen"
assert_eq "$(build_capture_cmd gnome window)" "gnome-screenshot --window --clipboard" "gnome window"

# Unknown mode yields empty string.
assert_eq "$(build_capture_cmd kde bogus)" "" "unknown mode is empty"

# main() dry-run: prints what it WOULD do, without touching the desktop.
tmp2="$(mktemp)"
printf 'AI_URL="https://example.com/ai"\nCAPTURE_MODE="region"\n' > "$tmp2"
out="$(DRY_RUN=1 XDG_CURRENT_DESKTOP=KDE SCREENSHOT_TO_AI_CONFIG="$tmp2" \
  bash bin/screenshot-to-ai.sh)"
assert_contains "$out" "RUN: spectacle --region --background --nonotify --copy-image" "main runs capture"
assert_contains "$out" "NOTIFY: Captured" "main notifies"
assert_contains "$out" "OPEN: https://example.com/ai" "main opens AI URL"
rm -f "$tmp2"

# main() with unknown desktop exits non-zero and reports it.
out2="$(DRY_RUN=1 XDG_CURRENT_DESKTOP=sway SCREENSHOT_TO_AI_CONFIG=/nonexistent \
  bash bin/screenshot-to-ai.sh; echo "EXIT:$?")"
assert_contains "$out2" "Unsupported desktop" "unknown desktop message"
assert_contains "$out2" "EXIT:1" "unknown desktop exits 1"

finish
