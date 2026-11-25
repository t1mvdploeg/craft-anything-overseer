(Watching Claude Code session on behalf of the user.)

This is a new conversation. Read HANDOFF.md, CLAUDE.md and the feature status file only as far as you need to.

## Fresh round

Goals for this round:
{{GOALS}}

Current state and open items (from the previous round):
{{STATE}}

## Frugal workflow

The user wants to save usage.
- You (the main agent) only plan, delegate and judge. Do not read big files yourself and do not build, merge or click yourself.
- All the work (building, fixing, merging, testing, clicking through with screenshots) is done by subagents: at most 3 Sonnet 5.5 subagents at the same time, each with one clear, small task and a short report back.
- Judge their reports and screenshots. If in doubt, send a targeted follow-up task.
- At the end: one review by one Opus 5.5 subagent over the whole round. Let Sonnet fix the findings.
- Then update HANDOFF.md and the feature status file.
- Do not end your turn while subagents are running. Wait for the normal completion notice.

## Never

These rules hold for you and for every subagent: copy this list into each subagent's task.

- `find /` or any search over the whole disk. Search only inside the app folder and your own work folder.
- ffmpeg without a guaranteed end (for example `tpad=stop=-1` pads forever).
- Blind `sleep` loops, or polling `tasks/*.output` files.
- Ending the turn while subagents are still running (they are killed about 10 minutes later).
- Starting console windows without hiding them (every ffmpeg/ffprobe/child process must start hidden).

## Resume variant

Use this instead of the text above after a Pause or a usage limit:

(Watching Claude Code session on behalf of the user.) The previous round was paused at {{PERCENT}} % of the usage limit, which has now reset. Continue where you were: finish the open items ({{OPEN_ITEMS}}), merge, test, copy the result into the app folder, and update HANDOFF.md and the feature status file. Same work method (Sonnet subagents; do not end your turn while subagents are running). Never `find /`, and no ffmpeg that does not stop.
