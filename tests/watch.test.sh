#!/bin/bash
# Plain-bash tests for monitor/watch.sh and monitor/round-usage.sh (poll for output instead of fixed sleeps)
M="$(cd "$(dirname "$0")/../skills/craft-anything-overseer/monitor" && pwd)"
T=$(mktemp -d -t watchtest.XXXXXX); D="$T/Craft Anything/proj"; mkdir -p "$D/checks/asks"
PIDS=""; trap 'kill $PIDS 2>/dev/null; rm -rf "$T"' EXIT
pass=0; failn=0
ok() { if [ "$2" = "1" ]; then pass=$((pass+1)); echo "ok   $1"; else failn=$((failn+1)); echo "FAIL $1"; fi; }
cnt() { grep -c "^$2" "$1" 2>/dev/null; }
# waitfor <file> <regex> [halfseconds=40]: poll until the regex appears
waitfor() { local i; for i in $(seq 1 ${3:-40}); do grep -q "$2" "$1" 2>/dev/null && return 0; sleep 0.5; done; return 1; }
export WATCH_INTERVAL=1 WATCH_STATUS_EVERY=2 WATCH_QUIET_SECONDS=3 WATCH_STATE_DIR="$T/state"
printf '10:00:00 said hello\n10:00:01 note x\n' > "$D/build-activity.log"
echo '{"items":[{"Step":{"step":"build","text":"x"}}]}' > "$D/feed.json"
run() { local n=$1; shift; env "$@" bash "$M/watch.sh" "$D" > "$T/$n.out" 2>&1 & PIDS="$PIDS $!"; }
stop() { kill $PIDS 2>/dev/null; wait 2>/dev/null; PIDS=""; }

# 1 usage missing: STATUS shows "usage ?%", no USAGE; QUESTION + QUIET + FAIL (start/FAIL pairs as in the real log)
run a WATCH_BUILDER_COUNT=1 WATCH_USAGE_FILE="$T/none.json"
waitfor $T/a.out '^STATUS'
echo '{"kind":"Check the build"}' > "$D/checks/asks/x.request.json"
echo '{"kind":"other"}' > "$D/checks/asks/y.request.json"
for i in 1 2 3 4 5; do echo "10:01:0$i start cmd $i" >> "$D/build-activity.log"; echo "10:01:0$i FAIL cmd $i (1 s)" >> "$D/build-activity.log"; done
waitfor $T/a.out '^QUIET'; waitfor $T/a.out '^FAIL'; waitfor $T/a.out '^QUESTION'; sleep 2; stop
o="$T/a.out"
ok "question y" $([ "$(cnt $o 'QUESTION y.request.json')" = 1 ] && echo 1)
ok "no question x" $(grep -q 'QUESTION x.request' $o || echo 1)
ok "status usage ?%" $(grep -q '^STATUS usage ?%, step build' $o && echo 1)
ok "no USAGE when missing" $(grep -q '^USAGE' $o || echo 1)
ok "one FAIL (start/FAIL pairs)" $([ "$(cnt $o 'FAIL 5x in a row')" = 1 ] && echo 1)
ok "one QUIET" $([ "$(cnt $o 'QUIET')" = 1 ] && echo 1)
ok "no DONE while building" $(grep -q '^DONE' $o || echo 1)

# 2 usage 86 -> one USAGE; expired resets_at -> unknown
echo '{"five_hour":{"used_percentage":86}}' > "$T/u.json"
run b WATCH_BUILDER_COUNT=1 WATCH_USAGE_FILE="$T/u.json"; waitfor $T/b.out '^USAGE'; sleep 2; stop
ok "one USAGE" $([ "$(cnt $T/b.out 'USAGE 86% >= 85%: pause')" = 1 ] && echo 1)
echo '{"rate_limits":{"five_hour":{"used_percentage":10}}}' > "$T/u2.json"
run b2 WATCH_BUILDER_COUNT=1 WATCH_USAGE_FILE="$T/u2.json"; waitfor $T/b2.out 'usage 10%'; stop
ok "real format, no USAGE, usage 10" $(grep -q 'usage 10%' $T/b2.out && ! grep -q '^USAGE' $T/b2.out && echo 1)
echo '{"rate_limits":{"five_hour":{"used_percentage":99,"resets_at":1000}}}' > "$T/u3.json"
run b3 WATCH_BUILDER_COUNT=1 WATCH_USAGE_FILE="$T/u3.json"; waitfor $T/b3.out '^STATUS'; sleep 2; stop
ok "expired resets_at: usage ?, no USAGE" $(grep -q '^STATUS usage ?%' $T/b3.out && ! grep -q '^USAGE' $T/b3.out && echo 1)
echo '{"rate_limits":{"five_hour":{"used_percentage":91,"resets_at":99999999999}}}' > "$T/u4.json"
run b4 WATCH_BUILDER_COUNT=1 WATCH_USAGE_FILE="$T/u4.json"; waitfor $T/b4.out '^USAGE'; stop
ok "future resets_at still counts" $(grep -q '^USAGE 91%' $T/b4.out && echo 1)
echo '{"rate_limits":{"seven_day":{"used_percentage":92,"resets_at":99999999999}}}' > "$T/u5.json"
run b5 WATCH_BUILDER_COUNT=1 WATCH_USAGE_FILE="$T/u5.json" WATCH_USAGE_WINDOW=seven_day; waitfor $T/b5.out '^USAGE'; stop
ok "WATCH_USAGE_WINDOW=seven_day" $(grep -q '^USAGE 92%' $T/b5.out && echo 1)

# 3 done + builders
echo '{"items":[{"User":"round 1"},{"Step":{"step":"done","text":"x"}}]}' > "$D/feed.json"
run c WATCH_BUILDER_COUNT=1; sleep 4; stop
ok "no DONE with builder" $(grep -q '^DONE' $T/c.out || echo 1)
run d WATCH_BUILDER_COUNT=0; waitfor $T/d.out '^DONE'; sleep 5; stop
ok "exactly one DONE" $([ "$(cnt $T/d.out DONE)" = 1 ] && echo 1)
ok "no QUIET while step is done" $(grep -q '^QUIET' $T/d.out || echo 1)
# C1: restart (same state) while idle must not re-fire DONE for the same round
run e WATCH_BUILDER_COUNT=0; sleep 4; stop
ok "restart does not re-fire DONE for a reported round" $(grep -q '^DONE' $T/e.out || echo 1)
# a new round (new "User":) that ends gets its DONE
echo '{"items":[{"User":"round 1"},{"User":"round 2"},{"Step":{"step":"done","text":"x"}}]}' > "$D/feed.json"
run f WATCH_BUILDER_COUNT=0; waitfor $T/f.out '^DONE'; stop
ok "new round gets its DONE" $(grep -q '^DONE' $T/f.out && echo 1)

# 5 ZERO TURN: one line per new 0-token turn
printf '10:00:00 said hi\n' > "$D/build-activity.log"
run z WATCH_BUILDER_COUNT=1 WATCH_USAGE_FILE="$T/none.json"; sleep 2
echo "10:05:00 note  The builder's turn ended (0 tokens in, 0 out)" >> "$D/build-activity.log"; waitfor $T/z.out '^ZERO TURN'
echo "10:06:00 note  The builder's turn ended (900 tokens in, 5 out)" >> "$D/build-activity.log"; sleep 3; stop
ok "one ZERO TURN, none for a real turn" $([ "$(cnt $T/z.out 'ZERO TURN')" = 1 ] && echo 1)
ok "to_win_path" $([ "$(bash "$M/watch.sh" --to-win-path "C:/a b/c")" = 'C:\a b\c' ] && echo 1)
# 4 round-usage
mkdir -p "$T/r"; printf 'turn ended (7 tokens in, 7 out)\nb\nc\n1 note The builder'"'"'s turn ended (100 tokens in, 5 out)\n2 note turn ended (100 tokens in, 5 out)\n' > "$T/r/build-activity.log"
ok "round-usage count" $([ "$(bash "$M/round-usage.sh" "$T/r")" = 5 ] && echo 1)
ok "round-usage sum" $([ "$(bash "$M/round-usage.sh" "$T/r" 3)" = "ROUND input=200 output=10 turns=2" ] && echo 1)

echo "passed $pass, failed $failn"; [ $failn = 0 ]
