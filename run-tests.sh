#!/usr/bin/env bash
# Runs raw-diff compare API for each fixture range and validates completeness.
set -uo pipefail
cd "$(dirname "$0")"
source fixtures.env
TOKEN=$(tr -d ' \t\r\n' < token.txt)
REPO="gtvb/diff-tests"
APIV="2022-11-28"
mkdir -p out
printf "%-12s %-6s %-11s %-7s %-7s %-8s %-9s %-8s\n" TEST HTTP bytes files endsNL gitApply expFiles match
for v in FC299 FC300 FC301 LINES_UNDER LINES_OVER SIZE_UNDER SIZE_OVER SF_UNDER SF_OVER SFL_UNDER SFL_OVER; do
  eval r=\$$v; b=${r%...*}; h=${r#*...}
  f="out/$v.diff"
  code=$(curl -s -w "%{http_code}" -o "$f" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github.diff" \
    -H "X-GitHub-Api-Version: $APIV" \
    "https://api.github.com/repos/$REPO/compare/$b...$h")
  bytes=$(wc -c < "$f" | tr -d ' ')
  files=$(grep -c '^diff --git' "$f" 2>/dev/null)
  nl=$([ "$(tail -c1 "$f" | xxd -p)" = "0a" ] && echo yes || echo NO)
  git apply --stat "$f" >/dev/null 2>&1 && ga=ok || ga=FAIL
  exp=$(git diff --name-only "$b" "$h" | wc -l | tr -d ' ')
  # ground-truth: set of expected filenames all present in returned diff
  miss=0
  while read -r fn; do grep -q "b/$fn$" "$f" || miss=$((miss+1)); done < <(git diff --name-only "$b" "$h")
  match=$([ "$miss" -eq 0 ] && echo yes || echo "NO(-$miss)")
  printf "%-12s %-6s %-11s %-7s %-7s %-8s %-9s %-8s\n" "$v" "$code" "$bytes" "$files" "$nl" "$ga" "$exp" "$match"
done
