#!/bin/bash
# watch.sh <project-dir> [threshold=85]: polls a Craft Anything project, prints one tagged line per event.
# Do not run it while the app is idle (between rounds) or paused: see SKILL.md.
to_win_path() { cygpath -w "$1" 2>/dev/null || echo "${1//\//\\}"; }
[ "$1" = --to-win-path ] && { to_win_path "$2"; exit 0; }
D="$1"; TH="${2:-85}"; L="$D/build-activity.log"
IV=${WATCH_INTERVAL:-15}; SE=${WATCH_STATUS_EVERY:-240}; QS=${WATCH_QUIET_SECONDS:-900}
UF="${WATCH_USAGE_FILE:-$HOME/.claude/usage-limits.json}"; UW="${WATCH_USAGE_WINDOW:-five_hour}"  # or seven_day
HELPER="$(cd "$(dirname "$0")/../windows" && pwd)/builder.ps1"
[ -f "$L" ] || { echo "no build-activity.log in $D" >&2; exit 1; }
# State outside the project: DONE already reported (keyed on the "User": count of feed.json) and seen questions.
ST="${WATCH_STATE_DIR:-${TMPDIR:-/tmp}}/watch-$(echo "$D" | cksum | cut -d' ' -f1)"; mkdir -p "$(dirname "$ST")"
users() { grep -o '"User":' "$D/feed.json" 2>/dev/null | wc -l | tr -d ' '; }
stepnow() { grep -o '"Step":{"step":"[a-z]*"' "$D/feed.json" 2>/dev/null | tail -1 | cut -d'"' -f6; }
n=$(wc -l < "$L")
[ -f "$ST.seen" ] && seen=$(cat "$ST.seen") || seen=$(ls "$D/checks/asks/" 2>/dev/null | sort)
quiet=0; sinceStatus=$SE; doneSaid=0; failSaid=0; quietSaid=0; usageSaid=0
# One shared builder rule lives in windows/builder.ps1 (claude.exe under craft-anything.exe, or project dir in its command line).
builders() {
  [ -n "${WATCH_BUILDER_COUNT+x}" ] && { echo "$WATCH_BUILDER_COUNT"; return; }
  [ "$(uname)" = Darwin ] && { bash "$(dirname "$HELPER")/../macos/find-hangs.sh" "$D" --count | awk '{print $2}'; return; }
  BH="$(to_win_path "$HELPER")" PD="$(to_win_path "$D")" powershell.exe -NoProfile -Command '. $env:BH; Show-Builders $env:PD' | tr -d '\r' | tail -1
}
# A restart must not repeat a DONE already reported for this round.
[ "$(stepnow)" = done ] && [ "$(cat "$ST.done" 2>/dev/null)" = "$(users)" ] && doneSaid=1
while true; do
  sleep "$IV"; quiet=$((quiet+IV)); sinceStatus=$((sinceStatus+IV))
  m=$(wc -l < "$L" 2>/dev/null || echo "$n")
  if [ "$m" -gt "$n" ]; then
    # a turn that ended with 0 tokens did nothing (pitfall 5): say so at once
    tail -n +"$((n+1))" "$L" | grep -q 'turn ended (0 tokens in' && echo "ZERO TURN"
    n=$m; quiet=0; quietSaid=0
  fi
  step=$(stepnow)
  # an idle or finished app is quiet by design
  [ "$step" != done ] && [ "$quiet" -ge "$QS" ] && [ $quietSaid = 0 ] && { echo "QUIET $((quiet/60)) min"; quietSaid=1; }
  # FAIL: the last 5 result lines (done/FAIL; 'start' lines in between do not count) are all failures
  res=$(grep -E '^[0-9:]{8} (done|FAIL) ' "$L" | tail -5)
  if [ "$(echo "$res" | grep -c ' FAIL ')" -ge 5 ]; then [ $failSaid = 0 ] && { echo "FAIL 5x in a row"; failSaid=1; }
  else echo "$res" | tail -1 | grep -q ' FAIL ' || failSaid=0; fi
  now=$(ls "$D/checks/asks/" 2>/dev/null | sort)
  for f in $(comm -13 <(echo "$seen") <(echo "$now") | grep 'request.json$'); do
    grep -q '"Check the build"' "$D/checks/asks/$f" 2>/dev/null || echo "QUESTION $f"
  done
  seen=$now; echo "$seen" > "$ST.seen"
  # DONE needs step done AND zero builder processes (Pause also shows Ready)
  if [ "$step" = done ]; then
    [ $doneSaid = 0 ] && [ "$(builders)" = 0 ] && { echo "DONE"; doneSaid=1; users > "$ST.done"; }
  else doneSaid=0; fi
  # usage: raw statusline dump (.rate_limits.five_hour) or just .five_hour; unknown ("?") when missing or resets_at has passed
  u=$(jq -r --arg w "$UW" --argjson now "$(date +%s)" '(.rate_limits[$w] // .[$w]) | select((.resets_at // 1e12) > $now) | .used_percentage // empty' "$UF" 2>/dev/null)
  u=${u%%.*}
  if [ -n "$u" ] && [ "$u" -ge "$TH" ] 2>/dev/null; then
    [ $usageSaid = 0 ] && { echo "USAGE ${u}% >= ${TH}%: pause"; usageSaid=1; }
  else usageSaid=0; fi
  if [ "$sinceStatus" -ge "$SE" ]; then
    sinceStatus=0
    echo "STATUS usage ${u:-?}%, step ${step:-?}, last activity $(tail -1 "$L" | cut -c1-8), turns $(grep -c 'turn ended' "$L") | $(grep ' said ' "$L" | tail -1 | cut -c1-160)"
  fi
done
