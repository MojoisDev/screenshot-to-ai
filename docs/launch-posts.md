# Launch Posts (drafts)

Ready-to-paste announcement copy. Adjust the repo URL if it changes.

Repo: https://github.com/MojoisDev/screenshot-to-ai

## One-line pitch

Circle to Search for the Linux desktop: press a hotkey, drag a box around
anything, and your screenshot lands in your chosen AI page — ready to paste and ask.

## Show HN

**Title:** Show HN: Screenshot to AI – "Circle to Search" for the Linux desktop

**Body:**
I wanted Android's "Circle to Search" on my Linux desktop, so I built a small,
no-daemon tool. Press a hotkey, drag a box around anything on screen, and your
browser opens to your chosen AI (Google AI Mode, ChatGPT, Perplexity, Gemini, or
Claude) with the image already on your clipboard — you just paste and ask.

It's a standalone Bash script plus an installer that wires up the hotkey. Works
on KDE and GNOME, Wayland or X11. Your normal PrtSc screenshot keeps working;
this is a separate, additive hotkey. MIT licensed.

KDE/Wayland is what I use and tested most; GNOME is tested but I'd love more
reports. Feedback welcome.

## r/linux & r/opensource

**Title:** I built "Circle to Search" for the Linux desktop (KDE & GNOME, MIT)

**Body:**
Press a hotkey → drag a box → your browser opens to your chosen AI with the
screenshot on the clipboard, ready to paste. No daemon, no browser lock-in — a
standalone script with a one-command installer that sets up the hotkey.

Works on KDE and GNOME (Wayland or X11). Configurable AI destination and hotkey.
Your existing PrtSc workflow is untouched.

Repo + demo GIF: https://github.com/MojoisDev/screenshot-to-ai

## r/kde

**Title:** Screenshot to AI — hotkey to send a Spectacle region straight to your AI

**Body:**
A small tool that uses Spectacle to grab a region to the clipboard and opens your
chosen AI page in one hotkey. Installs a command shortcut (activates after a
logout, the usual KDE quirk). Wayland clipboard is handled via wl-clipboard so the
image actually sticks. MIT, standalone script.

Repo + demo: https://github.com/MojoisDev/screenshot-to-ai

## r/gnome

**Title:** Screenshot to AI on GNOME — looking for test reports

**Body:**
Hotkey → drag a box → AI page opens with the screenshot on your clipboard. Uses
gnome-screenshot (+ wl-clipboard on Wayland). The GNOME custom keybinding is set
up by the installer and works immediately. I've tested it on Ubuntu/Wayland and
would love reports from other GNOME setups — there's a "GNOME test report" issue
template.

Repo + demo: https://github.com/MojoisDev/screenshot-to-ai
