#!/bin/bash
# macOS port of windows/gui.ps1 for the Craft Anything window. Needs cliclick (brew install cliclick) and,
# for the terminal running Claude Code: Accessibility (clicks, keys, window info) and Screen Recording (screenshots).
# Usage: gui.sh info  [--out <png>]
#        gui.sh click <x> <y> [--out <png>]
#        gui.sh paste <x> <y> <text> [--out <png>]   (clicks the field, Cmd+A, Cmd+V; never Esc)
# x/y are POINTS relative to the window's top-left. Screenshots are scaled to points, so a pixel
# measured in the saved png is the number to pass here (Retina-safe).
ID="${GUI_BUNDLE_ID:-ai.storyteller.craft-anything}"
ACTION="$1"; shift
OUT=""; ARGS=()
while [ $# -gt 0 ]; do [ "$1" = --out ] && { OUT="$2"; shift 2; continue; }; ARGS+=("$1"); shift; done

osa() { osascript -e "$1" 2>&1; }
pgrep -x craft-anything >/dev/null || { echo "no window"; exit 1; }
osa "tell application id \"$ID\" to activate" >/dev/null; sleep 0.4
front=$(osa 'tell application "System Events" to get bundle identifier of first process whose frontmost is true')
[ "$front" = "$ID" ] || { echo "not in front, refusing to click ($front)"; exit 2; }
# window bounds in points: x, y, w, h
b=$(osa "tell application \"System Events\" to tell (first process whose bundle identifier is \"$ID\") to get {position, size} of window 1")
IFS=', ' read -r WX WY WW WH <<< "$b"
[[ "$WX $WY $WW $WH" =~ ^-?[0-9]+\ -?[0-9]+\ [0-9]+\ [0-9]+$ ]] || { echo "no window bounds: $b (grant Accessibility to the terminal?)"; exit 1; }

if [ "$ACTION" = click ] || [ "$ACTION" = paste ]; then
  X="${ARGS[0]}"; Y="${ARGS[1]}"
  [[ "$X" =~ ^[0-9]+$ && "$Y" =~ ^[0-9]+$ ]] && [ "$X" -lt "$WW" ] && [ "$Y" -lt "$WH" ] || { echo "REFUSED: x y must be integers inside the ${WW}x${WH} window"; exit 2; }
fi
case "$ACTION" in
  info) echo "window $WX,$WY ${WW}x${WH} (points)" ;;
  click) cliclick "c:$((WX + ARGS[0])),$((WY + ARGS[1]))"; sleep 0.4 ;;
  paste)
    printf '%s' "${ARGS[2]}" | pbcopy
    cliclick "c:$((WX + ARGS[0])),$((WY + ARGS[1]))"; sleep 0.2
    osa 'tell application "System Events" to keystroke "a" using command down' >/dev/null
    osa 'tell application "System Events" to keystroke "v" using command down' >/dev/null; sleep 0.3 ;;
  *) echo "unknown action: $ACTION (info|click|paste)"; exit 2 ;;
esac
if [ -n "$OUT" ]; then
  screencapture -x -R "$WX,$WY,$WW,$WH" "$OUT" || { echo "screenshot failed"; exit 1; }  # without Screen Recording it may still "succeed" with wallpaper only: look at the png
  sips -z "$WH" "$WW" "$OUT" >/dev/null && echo "saved $WW x $WH"
fi
