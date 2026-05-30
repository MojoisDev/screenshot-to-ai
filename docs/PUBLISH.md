# Publish Checklist

Pre-launch steps for making this repo discoverable and welcoming.

## 1. Repository description & topics

Set via the `gh` CLI (authenticated maintainer):

```bash
gh repo edit MojoisDev/screenshot-to-ai \
  --description "Circle to Search for the Linux desktop — hotkey to screenshot a region straight into your AI of choice (KDE & GNOME)." \
  --add-topic linux \
  --add-topic kde \
  --add-topic gnome \
  --add-topic wayland \
  --add-topic screenshot \
  --add-topic ai \
  --add-topic bash \
  --add-topic productivity \
  --add-topic plasma \
  --add-topic desktop
```

Or in the GitHub web UI: repo home → **About** (gear icon) → set the description
and add the topics above.

## 2. Demo GIF

Record and commit the demo before announcing — it is the #1 adoption driver.

```bash
tools/record-demo.sh check        # confirm spectacle + ffmpeg are present
tools/record-demo.sh record       # perform the flow, stop in Spectacle, get docs/demo.gif
git add docs/demo.gif && git commit -m "docs: add demo GIF"
git push
```

Keep it under 8 MB so GitHub inlines it. If it's too big, re-run with
`--fps 10 --width 800`.

## 3. Final pre-launch checks

- [ ] `bash tests/run.sh` is green.
- [ ] README renders correctly on GitHub (GIF shows, no broken links).
- [ ] `docs/demo.gif` is committed and visible in the rendered README.
- [ ] Description and topics set (step 1).
- [ ] A release tag exists (optional): `git tag -a v1.0.0 -m "v1.0.0" && git push --tags`.

## 4. Announce

Use the drafts in [launch-posts.md](launch-posts.md).
