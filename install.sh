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

combo_to_gnome() {
  # "Meta+Shift+Z" -> "<Super><Shift>z". Last token is the key (lowercased);
  # the rest are modifiers wrapped in <>.
  local combo="$1" out="" i p
  local -a parts
  IFS='+' read -ra parts <<< "$combo"
  local last=$(( ${#parts[@]} - 1 ))
  for i in "${!parts[@]}"; do
    p="${parts[$i]}"
    if [ "$i" -eq "$last" ]; then
      out+="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')"
    else
      case "$p" in
        Meta|Super|Win) out+="<Super>" ;;
        Shift)          out+="<Shift>" ;;
        Ctrl|Control)   out+="<Control>" ;;
        Alt)            out+="<Alt>" ;;
      esac
    fi
  done
  printf '%s' "$out"
}

write_config() {
  # write_config <ai_url> — copy template, substitute AI_URL.
  local url="$1"
  local dest="${SCREENSHOT_TO_AI_CONFIG:-$HOME/.config/screenshot-to-ai/config}"
  mkdir -p "$(dirname "$dest")"
  cp "$SCRIPT_DIR/config/config.example" "$dest"
  # Escape characters that are special in a sed replacement (\ and &), so URLs
  # with query strings are written verbatim. Use a non-/ delimiter for slashes.
  local escaped
  escaped="$(printf '%s' "$url" | sed -e 's/[\\&]/\\&/g')"
  sed -i "s|^AI_URL=.*|AI_URL=\"$escaped\"|" "$dest"
}

setup_hotkey_kde() {
  # setup_hotkey_kde <combo>
  local combo="$1"
  local desktop_file="${KDE_DESKTOP_FILE:-$HOME/.local/share/applications/screenshot-to-ai.desktop}"
  mkdir -p "$(dirname "$desktop_file")"
  cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=Screenshot to AI
Comment=Capture a screen region and open your AI of choice
Exec=$BIN_DEST/screenshot-to-ai.sh
Icon=spectacle
Terminal=false
NoDisplay=true
X-KDE-GlobalAccel-CommandShortcut=true
EOF
  # Register the shortcut binding (skipped in tests via KDE_SKIP_KGLOBAL).
  if [ -z "${KDE_SKIP_KGLOBAL:-}" ] && command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kglobalshortcutsrc --group "screenshot-to-ai.desktop" \
      --key "_k_friendly_name" "Screenshot to AI"
    kwriteconfig6 --file kglobalshortcutsrc --group "screenshot-to-ai.desktop" \
      --key "_launch" "$combo,none,Screenshot to AI"
  fi
}

setup_hotkey_gnome() {
  # setup_hotkey_gnome <combo>
  local combo="$1"
  if ! command -v gsettings >/dev/null 2>&1; then
    return 0
  fi
  local schema="org.gnome.settings-daemon.plugins.media-keys"
  local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/screenshot-to-ai/"
  local binding list
  binding="$(combo_to_gnome "$combo")"

  list="$(gsettings get "$schema" custom-keybindings)"
  case "$list" in
    "@as []"|"[]")        list="['$path']" ;;
    *"$path"*)            : ;; # already present
    *)                    list="${list%]}, '$path']" ;;
  esac
  gsettings set "$schema" custom-keybindings "$list"
  gsettings set "$schema.custom-keybinding:$path" name "Screenshot to AI"
  gsettings set "$schema.custom-keybinding:$path" command "$BIN_DEST/screenshot-to-ai.sh"
  gsettings set "$schema.custom-keybinding:$path" binding "$binding"
}

detect_desktop_installer() {
  case "${XDG_CURRENT_DESKTOP:-}" in
    *KDE*) echo "kde" ;;
    *GNOME*) echo "gnome" ;;
    *) echo "unknown" ;;
  esac
}

main() {
  echo "Installing Screenshot to AI..."

  # 1. Copy the engine.
  mkdir -p "$BIN_DEST"
  cp "$SCRIPT_DIR/bin/screenshot-to-ai.sh" "$BIN_DEST/screenshot-to-ai.sh"
  chmod +x "$BIN_DEST/screenshot-to-ai.sh"
  echo "Installed engine to $BIN_DEST/screenshot-to-ai.sh"

  # 2. Choose an AI destination.
  echo
  echo "Choose your AI destination:"
  echo "  1) Google AI Mode (default)"
  echo "  2) ChatGPT"
  echo "  3) Perplexity"
  echo "  4) Google Gemini"
  echo "  5) Claude"
  echo "  6) Custom URL"
  printf "Selection [1]: "
  read -r choice
  choice="${choice:-1}"
  local url
  if [ "$choice" = "6" ]; then
    printf "Enter the full URL: "
    read -r url
  else
    url="$(ai_url_for_choice "$choice")"
  fi
  if [ -z "$url" ]; then
    echo "Invalid choice; defaulting to Google AI Mode."
    url="$(ai_url_for_choice 1)"
  fi
  write_config "$url"
  echo "Saved AI destination: $url"

  # 3. Choose the hotkey.
  echo
  printf "Hotkey combo [Meta+Shift+Z]: "
  read -r combo
  combo="${combo:-Meta+Shift+Z}"

  # 4. Register the hotkey for this desktop.
  local desktop
  desktop="$(detect_desktop_installer)"
  case "$desktop" in
    kde)
      setup_hotkey_kde "$combo"
      echo "Registered KDE shortcut: $combo"
      echo "NOTE: On KDE the shortcut activates after you log out and back in."
      ;;
    gnome)
      if setup_hotkey_gnome "$combo" && command -v gsettings >/dev/null 2>&1; then
        echo "Registered GNOME shortcut: $combo (active immediately)."
      else
        echo "Could not register the GNOME shortcut automatically (gsettings not found)."
        echo "The engine is installed at $BIN_DEST/screenshot-to-ai.sh — bind it to a key manually."
      fi
      ;;
    *)
      echo "Could not detect KDE or GNOME. The engine is installed at"
      echo "  $BIN_DEST/screenshot-to-ai.sh"
      echo "Bind it to a hotkey manually via your desktop's keyboard settings."
      ;;
  esac

  echo
  echo "Done. Press $combo, drag a box, then paste (Ctrl+V) into the AI page and ask."
}

# Run main only when executed directly (not when sourced by tests).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
