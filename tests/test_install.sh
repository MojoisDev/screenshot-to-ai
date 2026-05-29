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
