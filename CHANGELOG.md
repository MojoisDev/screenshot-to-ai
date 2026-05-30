# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-30

### Added
- Engine (`screenshot-to-ai.sh`): capture a screen region to the clipboard and
  open a configured AI page in the default browser.
- Capture modes: region (default), fullscreen, active window.
- Desktop support: KDE (spectacle) and GNOME (gnome-screenshot), with optional
  `BACKEND` override.
- Wayland clipboard handling on both KDE and GNOME via `wl-copy`, so the image
  survives after the screenshot tool exits.
- Loud failure when the capture backend is missing or capture fails (no false
  "success").
- Configurable AI destination (Google AI Mode, ChatGPT, Perplexity, Gemini,
  Claude, or a custom URL) and configurable hotkey.
- `install.sh`: copies the engine, runs an AI-destination picker, writes config,
  and registers the hotkey for KDE or GNOME.
- `uninstall.sh`: removes the engine, the hotkey/launcher, and optionally config.
- Dependency-free Bash test suite.
