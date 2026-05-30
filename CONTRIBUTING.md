# Contributing

Thanks for helping improve Screenshot to AI!

## Running the tests

The suite is dependency-free (plain Bash):

```bash
bash tests/run.sh
```

It runs `bash -n` syntax checks on every script plus the engine and installer
unit tests.

## Developing the engine

Use dry-run mode to see what the engine *would* do without touching your desktop:

```bash
DRY_RUN=1 XDG_CURRENT_DESKTOP=KDE bash bin/screenshot-to-ai.sh
```

It prints `RUN:` / `NOTIFY:` / `OPEN:` lines instead of capturing, notifying, or
opening a browser.

## Manual verification

Desktop integration (real capture, hotkey registration) can't be unit-tested.
Before submitting changes that touch capture or install logic, run the flow by
hand: `~/.local/bin/screenshot-to-ai.sh`, drag a box, confirm the image is on the
clipboard and the AI page opens.

## Commit style

Conventional Commits, matching the existing history:

- `feat(engine): ...`, `fix(gnome): ...`, `docs(readme): ...`, `chore: ...`

## Testing on GNOME

GNOME support needs more real-world reports. If you run GNOME (X11 or Wayland),
please open a **GNOME test report** issue with your results — it's the most
useful contribution right now.
