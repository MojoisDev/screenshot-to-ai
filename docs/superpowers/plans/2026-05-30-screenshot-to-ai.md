# Screenshot to AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a portable, no-daemon Linux desktop tool that captures a screen region to the clipboard and opens a chosen AI search page in the default browser, installed by a single script that also wires up a hotkey.

**Architecture:** A standalone Bash engine script (`bin/screenshot-to-ai.sh`) does the runtime work: load config → detect desktop (KDE/GNOME) → run the matching screenshot command for the chosen capture mode → notify → open the AI URL. A separate `install.sh` copies the engine, runs an AI-destination picker, writes config, and registers the hotkey per desktop. Both scripts are split into small sourceable functions so the pure logic is unit-testable; desktop-integration actions support a `DRY_RUN` mode and have a manual verification checklist.

**Tech Stack:** Bash, `spectacle` (KDE), `gnome-screenshot` (GNOME), `notify-send`, `xdg-open`/`setsid`, `kwriteconfig6` (KDE shortcut), `gsettings` (GNOME shortcut). Tests are dependency-free plain-Bash assertions plus `bash -n` syntax checks — no external test framework required.

---

## File Structure

- `bin/screenshot-to-ai.sh` — the engine. Sourceable functions: `load_config`, `detect_desktop`, `build_capture_cmd`, `run`, `notify`, `open_url`, `main`. Guarded so `main` runs only when executed directly.
- `config/config.example` — documented config template (the single source of truth for default AI URL and comments).
- `install.sh` — installer. Sourceable functions: `ai_url_for_choice`, `combo_to_gnome`, `write_config`, `setup_hotkey_kde`, `setup_hotkey_gnome`, `main`.
- `uninstall.sh` — removes engine, launcher/keybinding, optionally config.
- `tests/lib.sh` — tiny assertion harness (`assert_eq`, `assert_contains`, `finish`).
- `tests/run.sh` — runs every `tests/test_*.sh` and `bash -n` on all scripts.
- `tests/test_engine.sh`, `tests/test_install.sh` — the test suites.
- `README.md` — pitch, demo GIF placeholder, install, config, troubleshooting, roadmap.
- `LICENSE` — MIT.
- `.gitignore`.

---

### Task 1: Project scaffolding, license, and test harness

**Files:**
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `tests/lib.sh`
- Create: `tests/run.sh`

- [ ] **Step 1: Create the MIT license**

Create `LICENSE`:

```
MIT License

Copyright (c) 2026 mujeeb_25

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Create .gitignore**

Create `.gitignore`:

```
*.log
/tmp/
*.tmp
```

- [ ] **Step 3: Create the test assertion harness**

Create `tests/lib.sh`:

```bash
# Minimal dependency-free test harness.
TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
  # assert_eq <actual> <expected> <message>
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$1" = "$2" ]; then
    echo "PASS: $3"
  else
    echo "FAIL: $3"
    echo "  expected: [$2]"
    echo "  actual:   [$1]"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_contains() {
  # assert_contains <haystack> <needle> <message>
  TESTS_RUN=$((TESTS_RUN + 1))
  case "$1" in
    *"$2"*) echo "PASS: $3" ;;
    *)
      echo "FAIL: $3"
      echo "  expected to contain: [$2]"
      echo "  actual:              [$1]"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

finish() {
  echo "---"
  echo "$TESTS_RUN run, $TESTS_FAILED failed"
  [ "$TESTS_FAILED" -eq 0 ]
}
```

- [ ] **Step 4: Create the test runner**

Create `tests/run.sh`:

```bash
#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.." || exit 1

status=0

echo "== Syntax check (bash -n) =="
for f in bin/screenshot-to-ai.sh install.sh uninstall.sh; do
  if [ -f "$f" ]; then
    if bash -n "$f"; then echo "OK: $f"; else echo "SYNTAX FAIL: $f"; status=1; fi
  fi
done

echo "== Unit tests =="
for t in tests/test_*.sh; do
  [ -f "$t" ] || continue
  echo "-- $t --"
  if bash "$t"; then :; else status=1; fi
done

exit "$status"
```

- [ ] **Step 5: Make scripts executable and verify the harness runs**

Run:
```bash
chmod +x tests/run.sh
bash tests/run.sh
```
Expected: prints "== Syntax check ==" then "== Unit tests ==" with no test files yet, exits 0.

- [ ] **Step 6: Commit**

```bash
git add LICENSE .gitignore tests/lib.sh tests/run.sh
git commit -m "chore: project scaffolding, MIT license, test harness"
```

---

### Task 2: Engine — config loading with defaults

**Files:**
- Create: `bin/screenshot-to-ai.sh`
- Create: `tests/test_engine.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_engine.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_engine.sh`
Expected: FAIL — `bin/screenshot-to-ai.sh` does not exist / `load_config` not found.

- [ ] **Step 3: Write the minimal engine with load_config**

Create `bin/screenshot-to-ai.sh`:

```bash
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

# Run main only when executed directly (not when sourced by tests).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
```

Note: `main` is referenced by the guard but defined in a later task. Until then the
guard is unreachable in tests (they source the file, so `BASH_SOURCE[0] != $0`).

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_engine.sh`
Expected: 4 PASS, "4 run, 0 failed".

- [ ] **Step 5: Commit**

```bash
git add bin/screenshot-to-ai.sh tests/test_engine.sh
git commit -m "feat(engine): config loading with defaults"
```

---

### Task 3: Engine — desktop detection

**Files:**
- Modify: `bin/screenshot-to-ai.sh`
- Modify: `tests/test_engine.sh`

- [ ] **Step 1: Add failing tests**

In `tests/test_engine.sh`, insert before the `finish` line:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_engine.sh`
Expected: FAIL — `detect_desktop: command not found` (or unbound).

- [ ] **Step 3: Add detect_desktop**

In `bin/screenshot-to-ai.sh`, add after `load_config`:

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_engine.sh`
Expected: all PASS, "9 run, 0 failed".

- [ ] **Step 5: Commit**

```bash
git add bin/screenshot-to-ai.sh tests/test_engine.sh
git commit -m "feat(engine): desktop detection with backend override"
```

---

### Task 4: Engine — capture command builder

**Files:**
- Modify: `bin/screenshot-to-ai.sh`
- Modify: `tests/test_engine.sh`

- [ ] **Step 1: Add failing tests**

In `tests/test_engine.sh`, insert before `finish`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_engine.sh`
Expected: FAIL — `build_capture_cmd: command not found`.

- [ ] **Step 3: Add build_capture_cmd**

In `bin/screenshot-to-ai.sh`, add after `detect_desktop`:

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_engine.sh`
Expected: all PASS, "16 run, 0 failed".

- [ ] **Step 5: Commit**

```bash
git add bin/screenshot-to-ai.sh tests/test_engine.sh
git commit -m "feat(engine): capture command builder for KDE and GNOME"
```

---

### Task 5: Engine — main flow with dry-run helpers

**Files:**
- Modify: `bin/screenshot-to-ai.sh`
- Modify: `tests/test_engine.sh`

- [ ] **Step 1: Add a failing end-to-end dry-run test**

In `tests/test_engine.sh`, insert before `finish`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_engine.sh`
Expected: FAIL — no output because `main` is undefined (guard calls a missing function).

- [ ] **Step 3: Add helpers and main**

In `bin/screenshot-to-ai.sh`, add after `build_capture_cmd` (before the guard):

```bash
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

main() {
  load_config
  local desktop cmd
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
  run "$cmd"
  notify "Captured — opening AI"
  open_url "$AI_URL"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_engine.sh`
Expected: all PASS, "21 run, 0 failed".

- [ ] **Step 5: Run the full runner (syntax + tests)**

Run: `bash tests/run.sh`
Expected: `OK: bin/screenshot-to-ai.sh`, engine tests all pass, exit 0.

- [ ] **Step 6: Commit**

```bash
chmod +x bin/screenshot-to-ai.sh
git add bin/screenshot-to-ai.sh tests/test_engine.sh
git commit -m "feat(engine): main flow with dry-run, notify, and browser open"
```

---

### Task 6: Config example file

**Files:**
- Create: `config/config.example`
- Modify: `tests/test_engine.sh`

- [ ] **Step 1: Add a failing test that the example sources to the right default**

In `tests/test_engine.sh`, insert before `finish`:

```bash
# The shipped example config must source cleanly to the documented default.
( set -u
  # shellcheck disable=SC1091
  . config/config.example
  [ "$AI_URL" = "https://www.google.com/search?udm=50" ] || exit 1
  [ "$CAPTURE_MODE" = "region" ] || exit 1
)
assert_eq "$?" "0" "config.example sources to documented defaults"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_engine.sh`
Expected: FAIL — `config/config.example` does not exist.

- [ ] **Step 3: Create the example config**

Create `config/config.example`:

```bash
# Screenshot to AI — configuration.
# Copy to ~/.config/screenshot-to-ai/config (the installer does this for you).

# Where to send the screenshot. Pick one of the presets below or use any URL.
#   Google AI Mode : https://www.google.com/search?udm=50   (default)
#   ChatGPT        : https://chatgpt.com/
#   Perplexity     : https://www.perplexity.ai/
#   Google Gemini  : https://gemini.google.com/app
#   Claude         : https://claude.ai/new
AI_URL="https://www.google.com/search?udm=50"

# Capture mode: region | fullscreen | window
CAPTURE_MODE="region"

# Optional: force a screenshot backend if auto-detect guesses wrong.
# Valid values: spectacle | gnome-screenshot
# BACKEND="spectacle"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_engine.sh`
Expected: all PASS including "config.example sources to documented defaults".

- [ ] **Step 5: Commit**

```bash
git add config/config.example tests/test_engine.sh
git commit -m "feat: documented config.example template"
```

---

### Task 7: Installer — AI URL picker mapping and config writing

**Files:**
- Create: `install.sh`
- Create: `tests/test_install.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_install.sh`:

```bash
#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.." || exit 1
. tests/lib.sh

# Source installer functions without running main.
. install.sh

# AI URL preset mapping.
assert_eq "$(ai_url_for_choice 1)" "https://www.google.com/search?udm=50" "choice 1 = Google AI Mode"
assert_eq "$(ai_url_for_choice 2)" "https://chatgpt.com/" "choice 2 = ChatGPT"
assert_eq "$(ai_url_for_choice 3)" "https://www.perplexity.ai/" "choice 3 = Perplexity"
assert_eq "$(ai_url_for_choice 4)" "https://gemini.google.com/app" "choice 4 = Gemini"
assert_eq "$(ai_url_for_choice 5)" "https://claude.ai/new" "choice 5 = Claude"
assert_eq "$(ai_url_for_choice 9)" "" "invalid choice = empty"

# write_config copies the template and substitutes AI_URL.
tmp="$(mktemp)"
SCREENSHOT_TO_AI_CONFIG="$tmp" write_config "https://example.com/x"
got="$(grep '^AI_URL=' "$tmp")"
assert_eq "$got" 'AI_URL="https://example.com/x"' "write_config sets AI_URL"
# Comments from the template are preserved.
assert_contains "$(cat "$tmp")" "Capture mode:" "write_config keeps template comments"
rm -f "$tmp"

finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_install.sh`
Expected: FAIL — `install.sh` does not exist.

- [ ] **Step 3: Write the minimal installer with these two functions**

Create `install.sh`:

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_install.sh`
Expected: all PASS, "8 run, 0 failed".

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/test_install.sh
git commit -m "feat(install): AI URL picker mapping and config writer"
```

---

### Task 8: Installer — GNOME hotkey string conversion

**Files:**
- Modify: `install.sh`
- Modify: `tests/test_install.sh`

- [ ] **Step 1: Add failing tests**

In `tests/test_install.sh`, insert before `finish`:

```bash
# Convert a human combo (KDE style) to GNOME gsettings style.
assert_eq "$(combo_to_gnome 'Meta+Shift+Z')" "<Super><Shift>z" "Meta+Shift+Z -> GNOME"
assert_eq "$(combo_to_gnome 'Ctrl+Alt+P')" "<Control><Alt>p" "Ctrl+Alt+P -> GNOME"
assert_eq "$(combo_to_gnome 'Meta+S')" "<Super>s" "Meta+S -> GNOME"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_install.sh`
Expected: FAIL — `combo_to_gnome: command not found`.

- [ ] **Step 3: Add combo_to_gnome**

In `install.sh`, add after `ai_url_for_choice`:

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_install.sh`
Expected: all PASS, "11 run, 0 failed".

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/test_install.sh
git commit -m "feat(install): GNOME hotkey string converter"
```

---

### Task 9: Installer — KDE and GNOME hotkey setup functions

**Files:**
- Modify: `install.sh`
- Modify: `tests/test_install.sh`

These functions touch the live desktop config. The `.desktop` file write (KDE) is
verifiable with a path override; the `kglobalshortcutsrc`/`gsettings` registration is
**manually verified** in Task 12.

- [ ] **Step 1: Add a failing test for the KDE .desktop file content**

In `tests/test_install.sh`, insert before `finish`:

```bash
# setup_hotkey_kde writes a launcher .desktop with the command-shortcut flag.
tmpdesk="$(mktemp)"
KDE_DESKTOP_FILE="$tmpdesk" KDE_SKIP_KGLOBAL=1 setup_hotkey_kde "Meta+Shift+Z" >/dev/null 2>&1
content="$(cat "$tmpdesk")"
assert_contains "$content" "X-KDE-GlobalAccel-CommandShortcut=true" "kde launcher has accel flag"
assert_contains "$content" "Exec=$HOME/.local/bin/screenshot-to-ai.sh" "kde launcher Exec path"
assert_contains "$content" "Name=Screenshot to AI" "kde launcher name"
rm -f "$tmpdesk"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_install.sh`
Expected: FAIL — `setup_hotkey_kde: command not found`.

- [ ] **Step 3: Add setup_hotkey_kde and setup_hotkey_gnome**

In `install.sh`, add after `write_config`:

```bash
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
Exec=$HOME/.local/bin/screenshot-to-ai.sh
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
  gsettings set "$schema.custom-keybinding:$path" command "$HOME/.local/bin/screenshot-to-ai.sh"
  gsettings set "$schema.custom-keybinding:$path" binding "$binding"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_install.sh`
Expected: all PASS, "14 run, 0 failed".

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/test_install.sh
git commit -m "feat(install): KDE and GNOME hotkey registration"
```

---

### Task 10: Installer — main flow

**Files:**
- Modify: `install.sh`

`main` is interactive (prompts), so it is verified manually in Task 12 rather than
unit-tested. It must reuse the already-tested functions.

- [ ] **Step 1: Add main**

In `install.sh`, add after `setup_hotkey_gnome` (before the run guard):

```bash
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
      setup_hotkey_gnome "$combo"
      echo "Registered GNOME shortcut: $combo (active immediately)."
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
```

- [ ] **Step 2: Verify syntax and that the suite still passes**

Run: `bash tests/run.sh`
Expected: `OK: install.sh`, all unit tests pass, exit 0.

- [ ] **Step 3: Commit**

```bash
chmod +x install.sh
git add install.sh
git commit -m "feat(install): interactive main flow (copy, picker, hotkey)"
```

---

### Task 11: Uninstaller

**Files:**
- Create: `uninstall.sh`
- Modify: `tests/test_install.sh`

- [ ] **Step 1: Add a failing test for engine removal**

In `tests/test_install.sh`, insert before `finish`:

```bash
# remove_engine deletes the installed engine script.
tmpbin="$(mktemp -d)"
touch "$tmpbin/screenshot-to-ai.sh"
( . uninstall.sh; BIN_DEST="$tmpbin" remove_engine )
[ -e "$tmpbin/screenshot-to-ai.sh" ] && rc=1 || rc=0
assert_eq "$rc" "0" "remove_engine deletes the script"
rm -rf "$tmpbin"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_install.sh`
Expected: FAIL — `uninstall.sh` does not exist.

- [ ] **Step 3: Write uninstall.sh**

Create `uninstall.sh`:

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_install.sh`
Expected: all PASS, "15 run, 0 failed".

- [ ] **Step 5: Run the full runner**

Run: `bash tests/run.sh`
Expected: `OK: uninstall.sh`, all tests pass, exit 0.

- [ ] **Step 6: Commit**

```bash
chmod +x uninstall.sh
git add uninstall.sh tests/test_install.sh
git commit -m "feat: uninstaller for engine and hotkey"
```

---

### Task 12: README, manual verification, and final commit

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

Create `README.md`:

````markdown
# Screenshot to AI

**Circle to Search for the Linux desktop.** Press a hotkey, drag a box around
anything on screen, and your screenshot lands in your chosen AI page — ready to
paste and ask.

![demo](docs/demo.gif) <!-- TODO: record a 5-second demo GIF and place at docs/demo.gif -->

## How it works

1. Press your hotkey (default `Meta+Shift+Z`).
2. Drag a box around the thing you want to ask about.
3. Your browser opens to the AI you chose, with the image on your clipboard.
4. Click the search box, press **Ctrl+V**, type your question, hit Enter.

Your normal `PrtSc` screenshot keeps working exactly as before — this is a
separate, additive hotkey.

## Requirements

- **KDE** (uses `spectacle`) or **GNOME** (uses `gnome-screenshot`)
- `notify-send` (libnotify) for the capture confirmation
- A default browser (`xdg-open`)

## Install

```bash
git clone <your-repo-url> screenshot-to-ai
cd screenshot-to-ai
./install.sh
```

The installer copies the engine to `~/.local/bin`, asks which AI to use, asks for
your hotkey, and registers it.

- **KDE:** the shortcut activates after you **log out and back in** (KDE only loads
  command shortcuts at session start).
- **GNOME:** the shortcut works immediately.

## Configuration

Edit `~/.config/screenshot-to-ai/config`:

```bash
# Where to send the screenshot. Presets:
#   Google AI Mode : https://www.google.com/search?udm=50   (default)
#   ChatGPT        : https://chatgpt.com/
#   Perplexity     : https://www.perplexity.ai/
#   Google Gemini  : https://gemini.google.com/app
#   Claude         : https://claude.ai/new
AI_URL="https://www.google.com/search?udm=50"

# region | fullscreen | window
CAPTURE_MODE="region"

# Optional override: spectacle | gnome-screenshot
# BACKEND="spectacle"
```

To change the hotkey later: re-run `./install.sh`, or set it in your desktop's
keyboard settings (KDE: System Settings → Shortcuts; GNOME: Settings → Keyboard →
Custom Shortcuts).

## Supported setups

- **KDE Plasma 6 (Wayland):** tested.
- **GNOME:** community-tested — please report results.

## Troubleshooting

- **Hotkey does nothing (KDE):** log out and back in; KDE only registers command
  shortcuts at session start.
- **Browser didn't open:** the image is still on your clipboard; check that
  `xdg-open` works and you have a default browser set.
- **"Unsupported desktop":** auto-detect didn't find KDE/GNOME. Set `BACKEND` in the
  config and bind the hotkey manually.

## Uninstall

```bash
./uninstall.sh
```

## Roadmap

- Best-effort auto-paste (opt-in, via `ydotool`) so you skip Ctrl+V
- KDE Spectacle "Send to AI" entry (Purpose plugin) for native PrtSc integration
- OCR / text mode (grab the text in the region instead of the image)
- Also-save a copy of the screenshot to a folder
- Multiple hotkeys → multiple AIs
- Packaging: AUR and Flathub

## License

MIT — see [LICENSE](LICENSE).
````

- [ ] **Step 2: Run the full automated suite one last time**

Run: `bash tests/run.sh`
Expected: all syntax checks `OK`, all unit tests pass, exit 0.

- [ ] **Step 3: MANUAL verification on KDE (maintainer's machine)**

Perform by hand and confirm each:
1. `DRY_RUN=1 XDG_CURRENT_DESKTOP=KDE bash bin/screenshot-to-ai.sh` prints the
   spectacle RUN line, a NOTIFY line, and an OPEN line.
2. Run `./install.sh`, choose option 1, accept the default hotkey.
3. Confirm `~/.local/bin/screenshot-to-ai.sh` exists and `~/.config/screenshot-to-ai/config`
   has `AI_URL="https://www.google.com/search?udm=50"`.
4. Run `~/.local/bin/screenshot-to-ai.sh` directly: drag a box → a notification
   appears → browser opens to Google AI Mode → Ctrl+V pastes the image.
5. Log out and back in, press `Meta+Shift+Z`, repeat the full flow.
6. Run `./uninstall.sh`; confirm the engine and the
   `[screenshot-to-ai.desktop]` group in `~/.config/kglobalshortcutsrc` are gone.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: README with install, config, troubleshooting, roadmap"
```

---

## Notes for the implementer

- **TDD scope:** pure logic (`load_config`, `detect_desktop`, `build_capture_cmd`,
  `main` dry-run, `ai_url_for_choice`, `write_config`, `combo_to_gnome`,
  `setup_hotkey_kde` file output, `remove_engine`) is covered by automated tests.
  Live desktop registration and real capture are covered by the **manual checklist**
  in Task 12 — this is deliberate; they cannot be unit-tested without a session.
- **DRY_RUN=1** makes the engine print `RUN:`/`NOTIFY:`/`OPEN:` instead of acting —
  use it freely while developing.
- **Sourceable guard:** both `screenshot-to-ai.sh` and `install.sh`/`uninstall.sh`
  only run `main` when executed directly, so tests can source them safely.
- Keep commits as written — one per task step group.
````
