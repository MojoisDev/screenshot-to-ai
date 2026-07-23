# Screenshot to AI

[![Latest release](https://img.shields.io/github/v/release/MojoisDev/screenshot-to-ai?color=b8ff3d&label=release)](https://github.com/MojoisDev/screenshot-to-ai/releases)
[![License: MIT](https://img.shields.io/github/license/MojoisDev/screenshot-to-ai?color=57e0ff)](LICENSE)
![Platform: KDE & GNOME](https://img.shields.io/badge/desktop-KDE%20%7C%20GNOME-blue)
![Session: Wayland & X11](https://img.shields.io/badge/session-Wayland%20%7C%20X11-lightgrey)

**Circle to Search for the Linux desktop.** Press a hotkey, drag a box around
anything on screen, and your screenshot lands in your chosen AI page — ready to
paste and ask.

![Screenshot to AI: press a hotkey, drag a box around anything on screen, and it lands in your AI — ready to paste and ask (KDE & GNOME, Wayland & X11)](docs/hero.png)

## How it works

1. Press your hotkey (default `Meta+Shift+Z`).
2. Drag a box around the thing you want to ask about.
3. Your browser opens to the AI you chose, with the image on your clipboard.
4. Click the search box, press **Ctrl+V**, type your question, hit Enter.

Your normal `PrtSc` screenshot keeps working exactly as before — this is a
separate, additive hotkey.

## Requirements

- **KDE** (uses `spectacle`, ships with Plasma) or **GNOME** (uses `gnome-screenshot`)
  - On Ubuntu/Debian GNOME, install it if missing: `sudo apt install gnome-screenshot`
  - On GNOME **Wayland**, also install `wl-clipboard` so the screenshot stays on the clipboard: `sudo apt install wl-clipboard`
  - On KDE **Wayland**, also install `wl-clipboard`: `sudo apt install wl-clipboard`
- `notify-send` (libnotify) for the capture confirmation — **without it the tool still works, but you get no on-screen confirmation when the shot is taken.** Install on Debian/Ubuntu: `sudo apt install libnotify-bin`
- A default browser (`xdg-open`)

## Install

```bash
git clone https://github.com/MojoisDev/screenshot-to-ai.git screenshot-to-ai
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
- **GNOME (Ubuntu, Wayland):** tested — needs `gnome-screenshot` and `wl-clipboard` installed.
- **GNOME on X11:** should work (uses the direct clipboard path); reports welcome.

## Troubleshooting

- **Hotkey does nothing (KDE):** log out and back in; KDE only registers command
  shortcuts at session start.
- **Browser didn't open:** the image is still on your clipboard; check that
  `xdg-open` works and you have a default browser set.
- **"Unsupported desktop":** auto-detect didn't find KDE/GNOME. Set `BACKEND` in the
  config and bind the hotkey manually.
- **"Capture tool not found":** the screenshot backend isn't installed. On GNOME:
  `sudo apt install gnome-screenshot`. On KDE, install `spectacle`.
- **Browser opens but Ctrl+V pastes nothing (GNOME or KDE on Wayland):** install `wl-clipboard` (`sudo apt install wl-clipboard`). Wayland clears the clipboard when the screenshot tool exits; this keeps the image available to paste.

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
