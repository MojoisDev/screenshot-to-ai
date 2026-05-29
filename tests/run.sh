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
