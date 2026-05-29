# Screenshot to AI — Design Spec

**Date:** 2026-05-30
**Status:** Approved design, pre-implementation

## Summary

A small, no-daemon Linux desktop tool. The user presses a hotkey, drags a box
around any region of the screen, the image is copied to the clipboard, and their
chosen AI search page opens in the default browser — ready to paste (Ctrl+V) and
ask a question. In one line: **"Circle to Search for the Linux desktop."**

The novelty is OS-level capture on Linux that hands off to a browser-based AI,
working across desktops rather than being locked to one browser's built-in feature.

## Goals

- One hotkey → drag region → AI page open with the image on the clipboard.
- Portable across the two most common Linux desktops: **KDE and GNOME** (Wayland or X11).
- Works with whatever **default browser** the user has.
- Installed by a **single script** that also sets up the hotkey.
- Honest, low-maintenance, "just works" for a stranger who installs it.

## Non-Goals (v1)

- Full automatic paste/submit into the browser (see Roadmap — fragile on Wayland,
  browser-specific, deferred).
- A button inside the native screenshot dialog. Spectacle's toolbar cannot be
  extended; only its Export/Share menu can, via a KDE-only "Purpose" plugin. That
  is deferred to the Roadmap.
- Desktops beyond KDE and GNOME (Sway/wlroots, generic X11, etc.).
- System packaging (AUR, .deb, Flatpak) for the first release.

## What it is

A **standalone shell script** plus an **installer** and a **config file** — not a
plugin. The script runs on its own when the hotkey fires, does its job, and exits.
Being standalone (not embedded in any one app) is what lets it work on both KDE
and GNOME.

## Core flow

1. Hotkey fires the engine script.
2. Script detects the desktop and runs the matching screenshot command in the
   chosen capture mode, copying the image to the clipboard.
3. Script shows a brief confirmation notification.
4. Script opens the configured AI URL in the default browser (detached).
5. User clicks the search box, presses **Ctrl+V**, types a question, hits Enter.

This core (capture region to clipboard → open AI URL) is already proven working on
the maintainer's KDE Plasma 6 / Wayland machine.

## Features (v1)

1. **Configurable AI destination**, default Google AI Mode. The install-time picker
   offers a numbered list with the URL pre-filled for each option, and the user may
   also enter any custom URL. The choice is written to `AI_URL` in config. Shipped
   options:

   | AI | URL |
   |----|-----|
   | Google AI Mode (default) | `https://www.google.com/search?udm=50` |
   | ChatGPT | `https://chatgpt.com/` |
   | Perplexity | `https://www.perplexity.ai/` |
   | Google Gemini | `https://gemini.google.com/app` |
   | Claude | `https://claude.ai/new` |

   (`udm=50` is verified as Google AI Mode; the others are each service's normal
   entry page where the user pastes the screenshot.)
2. **Configurable hotkey** — the installer prompts for the key combo, defaulting to
   the suggested `Meta+Shift+Z`. The README documents how to change it later (KDE via
   System Settings → Shortcuts or re-running the installer; GNOME via the custom
   keybinding). The chosen combo is applied through the desktop-specific mechanism
   in the installer.
3. **Capture confirmation** — a small desktop notification when the shot is taken,
   so the user knows the hotkey fired.
4. **Capture modes** — region (default), full screen, active window; selected via
   config and/or a flag to the script.

## Architecture / components

```
ss Script/
├── bin/screenshot-to-ai.sh   ← engine: detect desktop, capture, notify, open AI
├── install.sh                ← copy files, pick AI, set up hotkey (KDE & GNOME)
├── uninstall.sh              ← remove everything cleanly
├── config/config.example     ← template the installer copies for the user
├── README.md                 ← what / install / config / troubleshooting / roadmap
└── LICENSE                   ← MIT
```

### Engine — `bin/screenshot-to-ai.sh`

- Reads config from `~/.config/screenshot-to-ai/config`.
- Detects desktop (KDE vs GNOME) to choose the screenshot backend:
  - **KDE:** `spectacle --region --background --nonotify --copy-image`
    (full-screen and active-window via the equivalent Spectacle flags).
  - **GNOME:** its area/full/window screenshot-to-clipboard equivalent.
  - Config may override the auto-detected backend (`BACKEND=`).
- Applies the configured capture mode.
- Shows a confirmation notification (`notify-send`).
- Opens `AI_URL` in the default browser, detached (`setsid xdg-open`), so the
  script returns immediately.
- On a cancelled selection, opening an empty AI tab is acceptable (the proven
  behavior); no fragile exit-code gate.

### Config — `~/.config/screenshot-to-ai/config`

Plain key=value so users never edit code:

```
# Where to send the screenshot. Pick one of the presets below or use any URL.
#   Google AI Mode : https://www.google.com/search?udm=50   (default)
#   ChatGPT        : https://chatgpt.com/
#   Perplexity     : https://www.perplexity.ai/
#   Google Gemini  : https://gemini.google.com/app
#   Claude         : https://claude.ai/new
AI_URL="https://www.google.com/search?udm=50"
# Capture mode: region | fullscreen | window
CAPTURE_MODE="region"
# Optional: force a screenshot backend if auto-detect guesses wrong
# BACKEND="spectacle"
```

The hotkey is not stored here — it lives in the desktop's own shortcut system
(set by the installer). Change it via the desktop's settings or by re-running
the installer.

### Installer — `install.sh`

1. Copy the engine to `~/.local/bin/` and make it executable.
2. Create the default config if none exists.
3. Prompt for the AI destination (numbered picker with URLs, or custom) and write `AI_URL`.
4. Prompt for the hotkey combo (default `Meta+Shift+Z`), then detect the desktop and
   set up that hotkey automatically:
   - **KDE:** write the `.desktop` launcher (`X-KDE-GlobalAccel-CommandShortcut=true`)
     and the `kglobalshortcutsrc` entry. Warn the user the binding **takes effect
     after logout/login** (kglobalaccel is hosted in kwin_wayland and only scans at
     session start).
   - **GNOME:** set a custom keybinding via `gsettings`. This activates immediately,
     no logout.
5. Print clear "you're done, here's how to use it" next steps.

### Uninstaller — `uninstall.sh`

Removes the engine, the launcher/keybinding entry, and (optionally) the config.

## Error handling

- Missing screenshot backend → notify the user with a clear message and exit.
- Unknown/unsupported desktop → fall back to a documented manual setup note.
- Browser open failure → notification; clipboard still holds the image.
- KDE hotkey not yet active → README troubleshooting explains the logout requirement.

## Testing approach

- Maintainer tests the **KDE path** end-to-end on their own machine (Plasma 6 / Wayland).
- The **GNOME path** is kept simple and well-documented, and marked
  **"community-tested"** in the README until a real GNOME user confirms it. We do not
  claim something works that we have not run.
- Verification checklist (per setup): capture-to-clipboard, confirmation appears,
  each capture mode, browser opens to the right AI URL, full manual paste flow,
  hotkey trigger.

## Documentation (README)

- Top: name, one-line pitch, and a **demo GIF** (press key → drag box → AI answers).
  The GIF is the primary adoption driver.
- Tested setups, install steps, config options.
- The one manual step (Ctrl+V + type the question).
- Troubleshooting: KDE logout quirk, "browser didn't open," backend-not-found.
- **Roadmap** section (see below).

## Roadmap (not built in v1)

- **Best-effort auto-paste** via `ydotool` (opt-in; falls back to manual). Fragile on
  Wayland and timing-dependent, hence deferred.
- **KDE Spectacle "Send to AI" entry** via a Purpose plugin — native integration into
  the normal PrtSc flow, KDE-only.
- **OCR / text mode** (extract the text from the region instead of the image; needs
  tesseract).
- **Also-save a copy** of the screenshot to a folder.
- **Multiple hotkeys → multiple AIs.**
- **Pre-filled question** via URL parameters where the destination supports it.
- System packaging: **AUR** and **Flathub**.

## License

MIT — permissive, standard for tools like this, best for adoption.

## Distribution / getting it known

- Host publicly on **GitHub** (home base).
- **Demo GIF** at the top of the README — the single most important asset.
- Clear name + one-line pitch.
- Share where the audience is: **r/linux, r/kde, r/gnome, r/opensource**, a
  **Show HN** post, **Lemmy** and **Mastodon** (#linux #kde #gnome), KDE/GNOME forums.
- Later: **AUR** + **Flathub** for discoverability; PRs to "awesome-linux"/"awesome-kde"
  lists.
