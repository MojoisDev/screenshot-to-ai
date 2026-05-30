#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.." || exit 1
. tests/lib.sh

# Source the tool without running main (guarded by BASH_SOURCE check).
. tools/record-demo.sh

# newest_video returns the most-recently-modified video file.
tmp="$(mktemp -d)"
: > "$tmp/a.webm"
: > "$tmp/b.mp4"
touch -d "2020-01-01" "$tmp/a.webm"
touch -d "2025-01-01" "$tmp/b.mp4"
assert_eq "$(newest_video "$tmp")" "$tmp/b.mp4" "newest_video returns most recent video"

# newest_video ignores non-video files.
rm -f "$tmp"/*
: > "$tmp/notes.txt"
assert_eq "$(newest_video "$tmp")" "" "newest_video ignores non-video files"
rm -rf "$tmp"

# spectacle_video_dir falls back to <home>/Videos when not configured.
assert_eq "$(HOME=/tmp/fake-sd-home spectacle_video_dir)" "/tmp/fake-sd-home/Videos" \
  "video dir defaults to ~/Videos"

finish
