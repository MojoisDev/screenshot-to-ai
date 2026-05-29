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

finish
