#!/bin/bash
# Claude Code statusline helper: saves .rate_limits from the statusline JSON (stdin) to a file
# (default ~/.claude/usage-limits.json) so the overseer's watch.sh can read the usage.
# Use it as a pipe snippet in your statusline script: input=$(cat); echo "$input" | bash write-usage.sh
# Prints nothing. No rate_limits in the input: the file is left untouched. Needs jq.
f="${1:-$HOME/.claude/usage-limits.json}"
j=$(jq -c 'select(.rate_limits != null) | {five_hour: .rate_limits.five_hour, seven_day: .rate_limits.seven_day}' 2>/dev/null)
[ -n "$j" ] || exit 0
mkdir -p "$(dirname "$f")" && printf '%s\n' "$j" > "$f.tmp.$$" && mv "$f.tmp.$$" "$f"
