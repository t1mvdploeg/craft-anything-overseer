#!/bin/bash
# macOS port of windows/find-hangs.ps1 + windows/builder.ps1.
# Usage: find-hangs.sh <project-dir> [--count] [--show] [--kill <pid>] [--min <minutes=10>]
#   --count  prints "BUILDERS <n>"
#   --show   prints each builder's command line and parent chain (first live round check)
#   --kill   kills <pid> only if it is a hang suspect (else "REFUSED ...", exit 3)
#   default  prints "HANG pid=.. age=..m name=.. cmd=.." lines or "NO HANGS"
# Builder = a claude process (name claude, or a .../claude/versions/<v> binary) that descends from
# craft-anything / craft-anything-cli, OR whose command line holds the project dir (followed by / " space or end),
# OR whose working directory is the project dir or inside it (catches a builder reparented to launchd).
# The calling session's own ancestors are never builders.
# Test hook: FH_PS=<file> with lines "pid<TAB>ppid<TAB>etime<TAB>comm<TAB>args[<TAB>cwd]" replaces the live ps.
D=""; MODE=hangs; KILL=""; MIN=10
while [ $# -gt 0 ]; do
  case "$1" in
    --count) MODE=count ;; --show) MODE=show ;;
    --kill) MODE=kill; KILL="$2"; shift ;; --min) MIN="$2"; shift ;;
    *) D="$1" ;;
  esac; shift
done
[ -n "$D" ] || { echo "project dir is required" >&2; exit 2; }
D="${D/#\~/$HOME}"; D="${D%/}"

ps_tsv() {
  if [ -n "$FH_PS" ]; then cat "$FH_PS"; return; fi
  # comm and args can both hold spaces: read them in two calls and join on pid
  ps -axww -o pid=,args= > "${TMPDIR:-/tmp}/fh-args.$$"
  ps -axww -o pid=,ppid=,etime=,comm= | awk -v af="${TMPDIR:-/tmp}/fh-args.$$" '
    BEGIN { while ((getline l < af) > 0) { sub(/^ +/, "", l); p = l; sub(/ .*/, "", p); a = l; sub(/^[0-9]+ ?/, "", a); A[p] = a } }
    { pid=$1; ppid=$2; et=$3; c=$0; sub(/^ *[0-9]+ +[0-9]+ +[^ ]+ /, "", c); cwd = ""
      b = c; sub(/.*\//, "", b)
      if (b == "claude" || c ~ /\/claude\/versions\//) { cmd = "lsof -a -d cwd -Fn -p " pid " 2>/dev/null"; while ((cmd | getline x) > 0) if (x ~ /^n/) cwd = substr(x, 2); close(cmd) }
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", pid, ppid, et, c, A[pid], cwd }'
  rm -f "${TMPDIR:-/tmp}/fh-args.$$"
}

ps_tsv | awk -F'\t' -v dir="$D" -v mode="$MODE" -v kill="$KILL" -v min="$MIN" -v self="$$" '
function base(s) { sub(/.*\//, "", s); return s }
function secs(e,   n, p, d) {  # etime [[dd-]hh:]mm:ss -> seconds
  d = 0; if (e ~ /-/) { d = e; sub(/-.*/, "", d); sub(/^[0-9]+-/, "", e) }
  n = split(e, p, ":"); return d*86400 + (n == 3 ? p[1]*3600 + p[2]*60 + p[3] : p[1]*60 + p[2])
}
function isClaude(i) { return base(comm[i]) == "claude" || comm[i] ~ /\/claude\/versions\// }
function underCA(i,   g, b) {
  for (g = 0; (i in ppid) && g < 30; g++) { i = ppid[i]; b = base(comm[i]); if (b == "craft-anything" || b == "craft-anything-cli") return 1 }
  return 0
}
function chain(i,   s, g) { s = ""; for (g = 0; i > 1 && (ppid[i] in comm) && g < 30; g++) { i = ppid[i]; s = s (s ? " <- " : "") base(comm[i]) "(" i ")" } return s }
{ pid[NR] = $1; ppid[$1] = $2; age[$1] = secs($3); comm[$1] = $4; args[$1] = $5; cwd[$1] = $6 }
END {
  for (i = self; (i in ppid) && i > 1; i = ppid[i]) mine[i] = 1
  n = 0
  for (k = 1; k <= NR; k++) { i = pid[k]
    if ((i in mine) || !isClaude(i)) continue
    a = args[i] " "; byPath = 0; L = length(dir)
    for (s = a; (p = index(s, dir)) > 0; s = substr(s, p + L)) if (substr(s, p + L, 1) ~ /[\/" ]/) { byPath = 1; break }
    if (cwd[i] == dir || index(cwd[i], dir "/") == 1) byPath = 1
    if (byPath || underCA(i)) { b[++n] = i; isB[i] = 1 }
  }
  if (mode == "count") { print "BUILDERS " n; exit }
  if (mode == "show") { for (k = 1; k <= n; k++) { print "builder pid=" b[k] " cmd=" args[b[k]]; print "  parents: " chain(b[k]) } print n; exit }
  # descendants of builders (a real child is never older than its parent: guards pid reuse)
  q = 0; for (k = 1; k <= n; k++) Q[++q] = b[k]
  for (h = 1; h <= q; h++) for (k = 1; k <= NR; k++) { c = pid[k]
    if (ppid[c] == Q[h] && !(c in seen) && age[c] <= age[Q[h]]) { seen[c] = 1; Q[++q] = c }
  }
  m = 0
  for (c in seen) { nm = base(comm[c])
    sus = nm == "find" || nm == "ffmpeg" || nm == "ffprobe" || ((nm == "bash" || nm == "sh" || nm == "zsh") && args[c] ~ /sleep/)
    if (sus && age[c] >= min * 60) { S[c] = 1; m++; line[m] = sprintf("HANG pid=%s age=%dm name=%s cmd=%s", c, age[c] / 60, nm, substr(args[c], 1, 200)) }
  }
  if (mode == "kill") { if (kill in S) { print "OK " kill } else { print "REFUSED pid " kill " is not a suspect" } exit }
  if (!m) print "NO HANGS"; else for (k = 1; k <= m; k++) print line[k]
}' > "${TMPDIR:-/tmp}/fh-out.$$"
out=$(cat "${TMPDIR:-/tmp}/fh-out.$$"); rm -f "${TMPDIR:-/tmp}/fh-out.$$"

if [ "$MODE" = kill ]; then
  case "$out" in OK*) ;; *) echo "$out"; exit 3 ;; esac
  [ -n "$FH_PS" ] && { echo "KILLED pid $KILL (test)"; exit 0; }
  kill -9 "$KILL" && echo "KILLED pid $KILL"; exit
fi
echo "$out"
