---
name: craft-anything-overseer
description: Use when a Claude Code session should watch and steer the Craft Anything desktop app while it rebuilds an app with its own claude builder session - send rounds, monitor, kill hangs, pause at the usage limit, check each round. Triggers "watch Craft Anything", "steer the builder", "/craft-anything-overseer"; Dutch triggers "kijk mee met Craft Anything", "stuur de bouwer", "houd Craft Anything in de gaten", "start de volgende ronde". Also when a relay continue for this skill arrives.
---

# Craft Anything overseer

You are the watcher. Craft Anything (CA) runs the builder (`claude -p`); you send rounds, monitor, unblock and check. Windows only. Everything you write for the builder is English. Messages to the user are short, answer first, in the user's language.

`S` = this skill's folder. Pitfalls with symptoms and fixes: `S\references\pitfalls.md` (numbers below refer to it). A worked example: `S\references\example.md`. In the Bash tool use forward slashes (`S/windows/...`) or the PowerShell tool; unquoted backslashes get lost in Bash.

## Never

- Write into `appDir`, the builder's `%APPDATA%` or the user's real data. Do not move or rename files under the project or work folders during a round (19). Exception: `checks` may build or test in `appDir` after DONE, never while a builder runs.
- Click Approvals, send Esc to CA (7, 8), or click when `gui.ps1` says "not in front" (17).
- Report "done" after a Pause: Ready is not finished (11).
- Poll so often that watching costs usage. Use the monitor and wakeups, not loops.
- Leave windows, monitors or stopgaps behind unnoted: list them in the handoff.
- Relay mid-action (see Relay).
- Write `"agent_session": ""`; it is always `null`.

## Attach

1. Read `handoffFile` first if it exists (a new day or a relayed session needs it). Read `craft-overseer.json` in the working folder. If missing, copy `S\craft-overseer.example.json` and fill it with the user (AskUserQuestion, few questions, recommended option first): `projectDir`, `appDir`, `issuesFile`, `handoffFile`, `goalsFile`, `usageFile`, `usageThreshold`, `buttons`, optional `relay`, `checks`, `screenshots`.
2. Goals list: if `goalsFile` is missing, draft it with the user. The user's OK on the list covers all rounds. You compose rounds from it and from the builder's open points and continue until the list is done. New features outside the list: ask the user first.
3. State: `pwsh -NoProfile -File S\windows\find-hangs.ps1 -ProjectDir <projectDir> -Count` prints `BUILDERS <n>`; the `watch.sh` STATUS line (step, usage; it prints at once); `gui.ps1 -action info`. Ready / run in progress / paused.
4. Relay (optional): if settings have `relay`, run `relay.arm`. If the command is missing or fails, say so once and go on without relay. Without `relay` there is no automatic relay: you never call a relay command, and you keep the handoff current by updating `handoffFile` after every round.
5. Unattended run (user away): ask the user to switch off screen lock and sleep (check `powercfg /requests`). A locked or sleeping PC breaks every click, including the Pause at the usage limit. Over a remote desktop do not disconnect in a way that locks the session.
6. Start the monitor (next section). Start the console-window closer hidden only if console windows actually pile up (18): `Start-Process pwsh -WindowStyle Hidden -ArgumentList '-NoProfile','-File','<S>\windows\close-console-windows.ps1','-TitleSuffix','\ffmpeg.exe,\ffprobe.exe'`; note its pid in the handoff.
7. First live round only: while a builder runs, `pwsh -NoProfile -Command ". '<S>\windows\builder.ps1'; Show-Builders '<projectDir>' -Show"` prints the builder's command line and parent chain. Check the count is >= 1 and the chain looks right (builder under `craft-anything.exe`, or the project dir in its command line). If the match does not work, tell the user: DONE, the watchdog and fresh-session cannot be trusted until the rule is fixed. Record what you saw in `handoffFile` (and in `issuesFile` if the match fails).

Paths: pass `-ProjectDir` to `find-hangs.ps1` and `fresh-session.ps1` as a Windows path with backslashes. `watch.sh` and `round-usage.sh` also accept forward slashes.

## Send a round

Only when no builder runs (STATUS step `done`, `find-hangs.ps1 -Count` prints `BUILDERS 0`) and usage is below `usageThreshold` (STATUS usage; `?` is unknown: read `usageFile` yourself). Not paused (see Usage limit).

1. Compose from `S\templates\round.md`: fill `{{GOALS}}` and `{{STATE}}`. Keep it frugal-workflow plus "Never" list as in the template.
2. Remember the log position: `bash S/monitor/round-usage.sh <projectDir>` prints the line count (`from`). Keep it in the handoff.
3. Fresh conversation: `pwsh -NoProfile -File S\windows\fresh-session.ps1 -ProjectDir <projectDir> -Label <round-name>` (`-Label` is `[a-z0-9-]+`, it becomes part of a file name). It closes CA first, then nulls `agent_session` and restarts CA. It prints the old `agent_session` id: note it. Needs `FRESH OK`; on `REFUSED:` read the reason (a builder is running, backup exists, exe not found), do not force. `-WhatIf` ends in `FRESH OK (whatif)` or `REFUSED (whatif): ...`. Wait until the CA window is up. Before the first overnight use, run one fresh-session between rounds with the user present.
4. Screenshot: `pwsh -NoProfile -File S\windows\gui.ps1 -proc craft-anything -action info -out <png>` prints the window size and saves the window; look at it. Check the window shows the right project name: CA reopens its last project, which may be another one (then stop and tell the user). If the size differs from `buttons.windowSize`, locate input and send again (16); `buttons` are only a starting point. Coordinates are relative to the window.
5. Paste (from Bash, multi-line text with quotes works): `pwsh -NoProfile -File "S/windows/gui.ps1" -action paste -x1 <inputX> -y1 <inputY> -text "$(cat round-12.txt)"` (it clicks the input, marks the whole field, pastes), then screenshot with `-out` and check the field. Empty (remote desktop): retry, then ask the user to paste (14).
6. Click send: `-action click -x1 <sendX> -y1 <sendY>`, exactly at the send button, never lower.
7. Verify: a new `"User":` in `feed.json`, `agent_session` in `craft.json` non-null and different from the old id that `fresh-session.ps1` printed, and `find-hangs.ps1 -Count` prints `BUILDERS 1` or more. Otherwise screenshot, retry once, then tell the user.

## Monitor

The usage file is written by the user's statusline with `statusline/write-usage.sh` (see the README); without it usage is `?`.

Start with the Monitor tool: `WATCH_USAGE_FILE=<usageFile> bash S/monitor/watch.sh <projectDir> <usageThreshold>` (`usageFile` as an absolute path; `~` expanded; if not set, the script defaults to `~/.claude/usage-limits.json`). Restart about every 25 minutes (15): stop the old watch first so there are no duplicates (it remembers the last DONE and the seen questions in a state file in the temp folder, so a restart does not repeat a DONE or lose a question). Run the monitor only while a round runs: not while idle (between rounds, waiting on the user) and not while paused. It prints one tagged line per event:

| Tag | Do |
|---|---|
| `DONE` | After a round. |
| `QUESTION <file>` | Builder Questions. |
| `QUIET <n> min` | Watchdog. Not sent while the step is `done`. |
| `FAIL 5x in a row` | 5 failed commands in a row (start lines do not count). Look at the log tail; tell the user if it is not an obvious transient. |
| `USAGE <u>% >= <th>%: pause` | Usage limit. |
| `STATUS usage ..%, step .., last activity .., turns .. \| last said` | Information only. `usage ?%` means unknown (file missing or its `resets_at` has passed), not a pause reason. |

Log times run one hour behind the clock (13): judge quiet by file time.

## Watchdog (on QUIET)

1. `pwsh -NoProfile -File S\windows\find-hangs.ps1 -ProjectDir <projectDir>` prints `HANG pid=.. age=..m name=.. cmd=..` lines or `NO HANGS`.
2. Kill an offender with `-Kill <pid>` (only suspects are allowed; `REFUSED ... exit 3` otherwise). Kill `find /`, endless ffmpeg, blind sleep loops (1, 10, 12).
3. Turn ended with 0 tokens in the log (5), or builder idle after a kill: send a short "continue" via the input field. Twice in a row: tell the user.
4. `NO HANGS` and still quiet: screenshot once, set a 15-minute wakeup, then run `find-hangs.ps1` again before asking the user (QUIET fires only once per quiet spell).

## Builder Questions

`checks\asks\*.request.json` (`QUESTION`). Read it.
- Technical, inside the goals: answer in the input field (during a run it becomes a note in `inbox\notes\`).
- About what the app should do, or cost: AskUserQuestion the user (or chat when no choice window); the run waits.
- Never through Approvals.

## Usage limit

On `USAGE`:
1. Only if a builder runs (`find-hangs.ps1 -Count` >= 1): press Pause (`buttons.pause`, screenshot first). If `gui.ps1` refuses (locked screen, "not in front"), PushNotification the user at once. Confirm builder processes end; a lingering `find-hangs.ps1` suspect may need a kill.
2. Stop the monitor: nothing runs while paused. Restart it after the resume.
3. Read `resets_at` (epoch seconds): `jq "(.rate_limits.five_hour // .five_hour).resets_at" <usageFile>`. Set a wakeup at `resets_at` + 2 min; for waits over an hour use CronCreate (one-shot) or chain wakeups; record it in the handoff as "paused".
4. Tell the user: paused at N %, resumes at HH:MM, they may switch accounts with `/login`. If they say they did, re-read usage and resume at once.
5. At the wakeup, re-read usage. If now < `resets_at` or usage is still >= `usageThreshold`, set a new wakeup and stop. Otherwise send the resume variant from `S\templates\round.md` (`{{PERCENT}}`, `{{OPEN_ITEMS}}`), restart the monitor, then confirm that tokens flow again (new `turn ended` lines with non-zero input).

## After a round

1. DONE rule: step `done` AND zero builder processes. A DONE after you pressed Pause (or while the handoff says paused) means paused, not finished: run no checks, wait for the wakeup.
2. Usage: `bash S/monitor/round-usage.sh <projectDir> <from>` prints `ROUND input=.. output=.. turns=..`. If the last `turn ended` in the log says `(0 tokens in`, or `ROUND input` is tiny, the round never ran: send a short "continue" (Watchdog step 3) instead of running checks. Otherwise note it with the % of the block in the handoff.
3. Run each entry of `checks` (`command` in `cwd`). Run the `screenshots` steps (2-3 screenshots, in a copy of test data, never real data); close the app windows you start.
4. Report to the user: result of checks, what changed, screenshots (visual work: show them in the chat), usage. PushNotification when done or when the user is needed.
5. Update `handoffFile` and say which .md files you updated.
6. Next round from the goals list, or tell the user that the list is done.
7. New odd CA behaviour goes into `issuesFile`, in English, GitHub-ready (symptom, steps, expected, actual).

## Relay (optional)

Only when settings have `relay` (`{ "arm": "...", "go": "... {handoff} ...", "percent": 40 }`). It is your own relay command: the skill does not ship one. Without `relay`: no automatic relay, you never call a relay command, and you update `handoffFile` after every round.

`relay.arm` is run on attach. Its hook sends a notice at `relay.percent` (default 40 %, "judge the moment") and at +10 % ("wrap up now").
- First notice: relay at the next good moment: the builder runs and the monitor is quiet, between rounds, or while waiting for a usage reset.
- Second notice: finish the current action, then relay.
- Never mid-action: pasting, fresh-session swap, killing a hang, composing a round. Finish it first.
- To relay, run `relay.go` with `{handoff}` replaced by `handoffFile`. Before that:
  - Write the handoff. First line: "Invoke craft-anything-overseer:craft-anything-overseer and resume." Then: run state and round, `from` log line, what is half done, open questions for the user, monitor and wakeup state (paused or running), processes the next session must know (window closer, stopgaps).
  - Stop your own monitors and delete your own wakeups (they belong to the old session).
  - If the command says "commit first", commit and run it again.
  - If it refuses for any other reason than "update the handoff first" or "commit first": restart the monitor and recreate the wakeup, tell the user, and carry on without relay.
- After "relayed": one line to the user, nothing more.
- The new session invokes this skill from the handoff, re-arms relay, restarts the monitor only if a round is running, recreates a due wakeup.

## Notify the user

PushNotification when available. Otherwise a message in the chat plus a line in the handoff. Ask first before deleting things, spending money, product decisions and account switches; everything else: decide, continue, report in one line.
