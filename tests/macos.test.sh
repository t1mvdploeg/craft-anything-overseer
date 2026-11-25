#!/bin/bash
# Plain-bash tests for skills/craft-anything-overseer/macos (fake ps input; never touches the real app)
M="$(cd "$(dirname "$0")/../skills/craft-anything-overseer/macos" && pwd)"
T=$(mktemp -d -t mactest.XXXXXX); trap 'rm -rf "$T"' EXIT
pass=0; failn=0
ok() { if [ "$2" = "1" ]; then pass=$((pass+1)); echo "ok   $1"; else failn=$((failn+1)); echo "FAIL $1"; fi; }
t=$'\t'
cat > "$T/ps" <<P
1${t}0${t}10-00:00:00${t}/sbin/launchd${t}/sbin/launchd
100${t}1${t}01:00:00${t}/Applications/Craft Anything.app/Contents/MacOS/craft-anything${t}/Applications/Craft Anything.app/Contents/MacOS/craft-anything
200${t}100${t}50:00${t}/opt/u/.local/share/claude/versions/2.1.3${t}claude -p --resume x
300${t}200${t}30:00${t}/usr/bin/find${t}find / -name x
301${t}200${t}02:00${t}/opt/homebrew/bin/ffmpeg${t}ffmpeg -i a
302${t}200${t}20:00${t}/bin/zsh${t}zsh -c until false; do sleep 30; done
303${t}200${t}20:00${t}/bin/bash${t}bash -c npm test
310${t}200${t}2-00:00:00${t}/usr/bin/find${t}find /
400${t}1${t}01:00:00${t}/opt/u/.local/bin/claude${t}claude --add-dir "/p/my-app"
403${t}1${t}01:00:00${t}/opt/u/.local/bin/claude${t}claude -p${t}/p/my-app/app
404${t}1${t}01:00:00${t}/opt/u/.local/bin/claude${t}claude -p${t}/p/my-app-2
401${t}1${t}01:00:00${t}/opt/u/.local/bin/claude${t}claude /p/my-app-2/x
402${t}1${t}01:00:00${t}/usr/bin/vim${t}vim /p/my-app/a
P
export FH_PS="$T/ps"
ok "count: parent + path + cwd match, not my-app-2, not vim" $([ "$(bash "$M/find-hangs.sh" /p/my-app/ --count)" = "BUILDERS 3" ] && echo 1)
h=$(bash "$M/find-hangs.sh" /p/my-app)
ok "find / is a hang" $(echo "$h" | grep -q '^HANG pid=300 age=30m name=find' && echo 1)
ok "zsh sleep loop is a hang" $(echo "$h" | grep -q '^HANG pid=302 ' && echo 1)
ok "young ffmpeg is not" $(echo "$h" | grep -q 'pid=301' || echo 1)
ok "npm test is not" $(echo "$h" | grep -q 'pid=303' || echo 1)
ok "older-than-parent pid reuse is not" $(echo "$h" | grep -q 'pid=310' || echo 1)
ok "kill suspect" $(bash "$M/find-hangs.sh" /p/my-app --kill 300 | grep -q '^KILLED pid 300' && echo 1)
bash "$M/find-hangs.sh" /p/my-app --kill 303 > "$T/k"; e=$?
ok "kill non-suspect refused, exit 3" $([ $e = 3 ] && grep -q '^REFUSED pid 303' "$T/k" && echo 1)
ok "--show prints parent chain" $(bash "$M/find-hangs.sh" /p/my-app --show | grep -q 'parents: craft-anything(100) <- launchd(1)$' && echo 1)

# fresh-session: refuses while a builder runs; whatif; real write with the app part skipped
P="$T/proj"; mkdir -p "$P" "$T/CA.app"; export FS_APP="$T/CA.app"
printf '{\n  "name": "x",\n  "agent_session": "abc-123",\n  "n": 1\n}\n' > "$P/craft.json"
head -1 "$T/ps" > "$T/ps-idle"; export FH_PS="$T/ps-idle"; cp "$T/ps-idle" "$T/ps-busy"; printf "500${t}1${t}01:00${t}/opt/u/.local/bin/claude${t}claude -p $P\n" >> "$T/ps-busy"
FH_PS="$T/ps-busy" bash "$M/fresh-session.sh" "$P" r1 > "$T/f0"
ok "refuses with a builder running" $(grep -q '^REFUSED: 1 builder' "$T/f0" && echo 1)
ok "bad label refused" $(bash "$M/fresh-session.sh" "$P" R_1 | grep -q 'REFUSED: label' && echo 1)
w=$(bash "$M/fresh-session.sh" "$P" r1 --whatif)
ok "whatif ok, prints old id" $(echo "$w" | grep -q 'old agent_session: abc-123' && echo "$w" | grep -q 'FRESH OK (whatif)' && echo 1)
ok "whatif leaves craft.json" $(grep -q '"abc-123"' "$P/craft.json" && [ ! -e "$P/craft.json.bak-r1" ] && echo 1)
FS_SKIP_APP=1 bash "$M/fresh-session.sh" "$P" r1 > "$T/f1"
ok "fresh ok" $(grep -q '^FRESH OK$' "$T/f1" && echo 1)
ok "agent_session null (not empty string)" $([ "$(jq -c .agent_session "$P/craft.json")" = null ] && echo 1)
ok "rest of craft.json kept" $([ "$(jq -c '[.name,.n]' "$P/craft.json")" = '["x",1]' ] && echo 1)
ok "backup holds old id" $(grep -q '"abc-123"' "$P/craft.json.bak-r1" && echo 1)
ok "second run with same label refused" $(FS_SKIP_APP=1 bash "$M/fresh-session.sh" "$P" r1 | grep -q 'backup already exists' && echo 1)
mkdir -p "$T/p2"; cp "$P/craft.json.bak-r1" "$T/p2/craft.json"
ok "--no-open + tilde path" $(HOME="$T" FS_SKIP_APP= FS_APP="$T/CA.app" PATH="$T/bin:$PATH" bash "$M/fresh-session.sh" "~/p2" r2 --whatif --no-open | grep -q "FRESH OK (whatif)" && echo 1)
echo "passed $pass, failed $failn"; [ $failn = 0 ]
