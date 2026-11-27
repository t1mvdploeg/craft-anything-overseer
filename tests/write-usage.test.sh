#!/bin/bash
# Plain-bash tests for statusline/write-usage.sh
S="$(cd "$(dirname "$0")/../statusline" && pwd)/write-usage.sh"
T=$(mktemp -d -t usagetest.XXXXXX); trap 'rm -rf "$T"' EXIT
pass=0; failn=0
ok() { if [ "$2" = "1" ]; then pass=$((pass+1)); echo "ok   $1"; else failn=$((failn+1)); echo "FAIL $1"; fi; }
F="$T/usage.json"
out=$(echo '{"model":"x","rate_limits":{"five_hour":{"used_percentage":42,"resets_at":1900000000},"seven_day":{"used_percentage":7,"resets_at":1900500000}}}' | bash "$S" "$F")
ok "writes five_hour 42" $([ "$(jq .five_hour.used_percentage "$F")" = 42 ] && echo 1)
ok "writes seven_day 7" $([ "$(jq .seven_day.used_percentage "$F")" = 7 ] && echo 1)
ok "prints nothing" $([ -z "$out" ] && echo 1)
ok "no temp file left" $([ "$(ls "$T" | wc -l | tr -d " ")" = 1 ] && echo 1)
echo '{"model":"x"}' | bash "$S" "$F"
ok "no rate_limits: file unchanged" $([ "$(jq .five_hour.used_percentage "$F")" = 42 ] && echo 1)
G="$T/new.json"; echo '{}' | bash "$S" "$G"
ok "no rate_limits: no file created" $([ ! -e "$G" ] && echo 1)
echo "$pass passed, $failn failed"; [ "$failn" = 0 ]
