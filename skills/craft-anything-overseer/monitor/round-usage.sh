#!/bin/bash
# round-usage.sh <project-dir> [from-line]: no line -> print current line count; else sum token usage after that line.
L="$1/build-activity.log"
[ -f "$L" ] || { echo "no build-activity.log in $1" >&2; exit 1; }
[ -z "$2" ] && { wc -l < "$L" | tr -d ' '; exit 0; }
tail -n +"$(($2+1))" "$L" | sed -nE 's/.*turn ended \(([0-9]+) tokens in, ([0-9]+) out\).*/\1 \2/p' |
  awk '{i+=$1; o+=$2; n++} END {printf "ROUND input=%d output=%d turns=%d\n", i, o, n}'
