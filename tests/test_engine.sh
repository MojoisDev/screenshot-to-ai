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

# KDE capture commands (X11 session: direct --copy-image works).
XDG_SESSION_TYPE="x11"
assert_eq "$(build_capture_cmd kde region)" \
  "spectacle --region --background --nonotify --copy-image" "kde region (x11)"
assert_eq "$(build_capture_cmd kde fullscreen)" \
  "spectacle --fullscreen --background --nonotify --copy-image" "kde fullscreen (x11)"
assert_eq "$(build_capture_cmd kde window)" \
  "spectacle --activewindow --background --nonotify --copy-image" "kde window (x11)"

# KDE on Wayland: must route through wl-copy via the helper.
XDG_SESSION_TYPE="wayland"
assert_eq "$(build_capture_cmd kde region)" "capture_kde_wayland --region" "kde region (wayland)"
assert_eq "$(build_capture_cmd kde fullscreen)" "capture_kde_wayland --fullscreen" "kde fullscreen (wayland)"
assert_eq "$(build_capture_cmd kde window)" "capture_kde_wayland --activewindow" "kde window (wayland)"
unset XDG_SESSION_TYPE

# GNOME capture commands per mode (X11 session: direct --clipboard works).
XDG_SESSION_TYPE="x11"
assert_eq "$(build_capture_cmd gnome region)" "gnome-screenshot --area --clipboard" "gnome region (x11)"
assert_eq "$(build_capture_cmd gnome fullscreen)" "gnome-screenshot --clipboard" "gnome fullscreen (x11)"
assert_eq "$(build_capture_cmd gnome window)" "gnome-screenshot --window --clipboard" "gnome window (x11)"

# GNOME on Wayland: must route through wl-copy via the helper.
XDG_SESSION_TYPE="wayland"
assert_eq "$(build_capture_cmd gnome region)" "capture_gnome_wayland --area" "gnome region (wayland)"
assert_eq "$(build_capture_cmd gnome fullscreen)" "capture_gnome_wayland" "gnome fullscreen (wayland)"
assert_eq "$(build_capture_cmd gnome window)" "capture_gnome_wayland --window" "gnome window (wayland)"
unset XDG_SESSION_TYPE

# Unknown mode yields empty string.
assert_eq "$(build_capture_cmd kde bogus)" "" "unknown mode is empty"

# main() dry-run: prints what it WOULD do, without touching the desktop.
tmp2="$(mktemp)"
printf 'AI_URL="https://example.com/ai"\nCAPTURE_MODE="region"\n' > "$tmp2"
out="$(DRY_RUN=1 XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=x11 SCREENSHOT_TO_AI_CONFIG="$tmp2" \
  bash bin/screenshot-to-ai.sh)"
assert_contains "$out" "RUN: spectacle --region --background --nonotify --copy-image" "main runs capture"
assert_contains "$out" "NOTIFY: Captured" "main notifies"
assert_contains "$out" "OPEN: https://example.com/ai" "main opens AI URL"
rm -f "$tmp2"

# main() on KDE Wayland routes capture through the wl-copy helper.
tmpw="$(mktemp)"
printf 'AI_URL="https://example.com/ai"\nCAPTURE_MODE="region"\n' > "$tmpw"
outw="$(DRY_RUN=1 XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland SCREENSHOT_TO_AI_CONFIG="$tmpw" \
  bash bin/screenshot-to-ai.sh)"
assert_contains "$outw" "RUN: capture_kde_wayland --region" "main (KDE wayland) uses wl-copy helper"
rm -f "$tmpw"

# main() with unknown desktop exits non-zero and reports it.
out2="$(DRY_RUN=1 XDG_CURRENT_DESKTOP=sway SCREENSHOT_TO_AI_CONFIG=/nonexistent \
  bash bin/screenshot-to-ai.sh; echo "EXIT:$?")"
assert_contains "$out2" "Unsupported desktop" "unknown desktop message"
assert_contains "$out2" "EXIT:1" "unknown desktop exits 1"

# The shipped example config must source cleanly to the documented default.
( set -u
  # shellcheck disable=SC1091
  . config/config.example
  [ "$AI_URL" = "https://www.google.com/search?udm=50" ] || exit 1
  [ "$CAPTURE_MODE" = "region" ] || exit 1
)
assert_eq "$?" "0" "config.example sources to documented defaults"

# backend_available reports whether the capture binary is on PATH.
backend_available "bash --version" && rc=0 || rc=1
assert_eq "$rc" "0" "backend_available true for present binary"
backend_available "definitely-not-a-real-binary-xyz --area --clipboard" && rc=0 || rc=1
assert_eq "$rc" "1" "backend_available false for missing binary"

finish
