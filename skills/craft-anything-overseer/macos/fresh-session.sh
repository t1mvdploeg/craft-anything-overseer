#!/bin/bash
# macOS port of windows/fresh-session.ps1: quit Craft Anything, back up craft.json, null agent_session, reopen.
# Usage: fresh-session.sh <project-dir> <label [a-z0-9-]+> [--whatif] [--no-open]
#   --no-open  quit and null but do not reopen the GUI (CLI route: one writer on craft.json)
# Test hooks: FS_APP=<.app path> (default /Applications/Craft Anything.app), FS_SKIP_APP=1 (no quit/open).
D="${1/#\~/$HOME}"; D="${D%/}"; LABEL="$2"; WHATIF=""; NOOPEN=""
for a in "${@:3}"; do [ "$a" = --whatif ] && WHATIF=1; [ "$a" = --no-open ] && NOOPEN=1; done
APP="${FS_APP:-/Applications/Craft Anything.app}"
refuse() { [ -n "$WHATIF" ] && echo "REFUSED (whatif): $1" || echo "REFUSED: $1"; exit 4; }
session() { perl -0ne 'print /"agent_session"\s*:\s*"((?:[^"\\]|\\.)*)"/ ? $1 : "null"' "$1"; }

[ -n "$D" ] && [ -n "$LABEL" ] || { echo 'REFUSED: <project-dir> and <label> are required'; exit 4; }
[[ "$LABEL" =~ ^[a-z0-9-]+$ ]] || refuse 'label must match [a-z0-9-]+'
C="$D/craft.json"; BAK="$C.bak-$LABEL"
[ -f "$C" ] || refuse "craft.json missing in $D"
[ -e "$BAK" ] && refuse "backup already exists: $BAK"
n=$(bash "$(dirname "$0")/find-hangs.sh" "$D" --count | awk '{print $2}')
[ "$n" = 0 ] || refuse "$n builder claude running (a Craft Anything builder)"
[ -d "$APP" ] || refuse "Craft Anything not found at $APP"

echo "old agent_session: $(session "$C")"
echo "backup -> craft.json.bak-$LABEL"
echo 'agent_session -> null'
[ -n "$WHATIF" ] && { echo "would quit Craft Anything, write craft.json, open $APP"; echo 'FRESH OK (whatif)'; exit 0; }

# 0. The builder (claude -p, cwd = project) stops background subagents 10 min after its turn ends unless
#    CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0 (pitfall 2). CA passes the builder a filtered environment, so set it
#    in the project's local Claude Code settings, which the builder reads.
S="$D/.claude/settings.local.json"; mkdir -p "$D/.claude"; [ -s "$S" ] || echo '{}' > "$S"
jq '.env.CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS = "0"' "$S" > "$S.tmp" && mv "$S.tmp" "$S" && echo 'builder setting: CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0'

# 1. Quit the app FIRST: it rewrites craft.json while it runs and on exit, which would undo the null.
if [ -z "$FS_SKIP_APP" ]; then
  osascript -e 'tell application id "ai.storyteller.craft-anything" to quit' >/dev/null 2>&1 || osascript -e "quit app \"$APP\"" >/dev/null 2>&1
  for i in $(seq 30); do pgrep -x craft-anything >/dev/null || break; sleep 0.5; done
  pkill -x craft-anything && sleep 1
  echo 'closed craft-anything'
fi

# 2. Only now touch craft.json (re-read: the app may have written it on exit).
echo "old agent_session (after close): $(session "$C")"
cp -p "$C" "$BAK" || refuse 'backup failed'
grep -q '"agent_session"' "$C" || echo 'WARNING: agent_session key not found; craft.json unchanged' >&2
perl -0pi -e 's/"agent_session"\s*:\s*("(?:[^"\\]|\\.)*"|null)/"agent_session": null/g' "$C"

# 3. Reopen. `open` starts it through launchd, so the watcher's CLAUDECODE/CLAUDE_CODE_* variables do not leak in.
if [ -z "$FS_SKIP_APP$NOOPEN" ]; then open -a "$APP" && echo "started $APP"; fi
echo 'NOTE: the app may reopen another project (last_project): check the window shows the right project name.'
echo 'FRESH OK'
