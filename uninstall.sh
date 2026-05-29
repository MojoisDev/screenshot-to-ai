#!/usr/bin/env bash
#
# uninstall.sh — remove Screenshot to AI: engine, launcher/keybinding, config.
set -u

BIN_DEST="${BIN_DEST:-$HOME/.local/bin}"

remove_engine() {
  rm -f "$BIN_DEST/screenshot-to-ai.sh"
}

remove_hotkey_kde() {
  local desktop_file="${KDE_DESKTOP_FILE:-$HOME/.local/share/applications/screenshot-to-ai.desktop}"
  rm -f "$desktop_file"
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kglobalshortcutsrc --group "screenshot-to-ai.desktop" --delete-group 2>/dev/null || true
  fi
}

remove_hotkey_gnome() {
  command -v gsettings >/dev/null 2>&1 || return 0
  local schema="org.gnome.settings-daemon.plugins.media-keys"
  local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/screenshot-to-ai/"
  local list
  list="$(gsettings get "$schema" custom-keybindings 2>/dev/null || echo "[]")"
  # Drop our path from the list (handles ", '<path>'" and "'<path>'").
  list="${list//, \'$path\'/}"
  list="${list//\'$path\', /}"
  list="${list//\'$path\'/}"
  gsettings set "$schema" custom-keybindings "$list" 2>/dev/null || true
}

main() {
  remove_engine
  echo "Removed engine."
  case "${XDG_CURRENT_DESKTOP:-}" in
    *KDE*)   remove_hotkey_kde;   echo "Removed KDE shortcut (logout to clear fully)." ;;
    *GNOME*) remove_hotkey_gnome; echo "Removed GNOME shortcut." ;;
  esac
  printf "Also delete config at ~/.config/screenshot-to-ai? [y/N]: "
  read -r ans
  case "$ans" in
    y|Y) rm -rf "$HOME/.config/screenshot-to-ai"; echo "Config deleted." ;;
    *)   echo "Config kept." ;;
  esac
  echo "Uninstalled."
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
