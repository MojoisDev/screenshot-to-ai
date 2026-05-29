#!/usr/bin/env bash
#
# install.sh — set up Screenshot to AI: copy the engine, choose an AI
# destination, write config, and register the hotkey for KDE or GNOME.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="${BIN_DEST:-$HOME/.local/bin}"

ai_url_for_choice() {
  case "$1" in
    1) echo "https://www.google.com/search?udm=50" ;;
    2) echo "https://chatgpt.com/" ;;
    3) echo "https://www.perplexity.ai/" ;;
    4) echo "https://gemini.google.com/app" ;;
    5) echo "https://claude.ai/new" ;;
    *) echo "" ;;
  esac
}

write_config() {
  # write_config <ai_url> — copy template, substitute AI_URL.
  local url="$1"
  local dest="${SCREENSHOT_TO_AI_CONFIG:-$HOME/.config/screenshot-to-ai/config}"
  mkdir -p "$(dirname "$dest")"
  cp "$SCRIPT_DIR/config/config.example" "$dest"
  # Replace the AI_URL line; use a non-/ delimiter since URLs contain slashes.
  sed -i "s|^AI_URL=.*|AI_URL=\"$url\"|" "$dest"
}

# Run main only when executed directly (not when sourced by tests).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
