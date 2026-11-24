# Worked example: my-app

A fictional setup, for orientation only. Your project will differ.

**Project:** a small desktop notes app (`my-app`) rebuilt in Craft Anything.

**Folders**
- Craft Anything project: `%USERPROFILE%\Documents\Craft Anything\my-app` (note the space; quote it everywhere).
- The app being built: `...\my-app\app\` (only the builder writes here), with its own `HANDOFF.md` and `CLAUDE.md`.
- Watcher working folder: `%USERPROFILE%\Documents\my-app-watch` (holds `craft-overseer.json`, the issues list, the round prompts).
- Round prompts are saved as UTF-8 `.txt` files and pasted with `gui.ps1`.

**Checks:** `npm test` in the app folder. A test data folder through the `MY_APP_HOME` environment variable, so real user data is never touched.

**Button positions** with the Craft Anything window at 1280x960: input field (600,820), send (930,870), Pause (850,860). These numbers are made up; measure your own, and again whenever the window size changes.

**Round flow:** fresh conversation (app closed, `agent_session` null, reopened), paste the round prompt, send, monitor, pause near the usage threshold, resume with a short prompt, after the round run the checks and take 2-3 screenshots (the app on sample data, the changed feature).

**Pitfalls seen:** `find /` hung for 20-30 minutes; an ffmpeg filter without an end ran for 90 minutes; many console windows from ffmpeg calls slowed the PC; the build log ran an hour behind the clock; pasting over a remote desktop failed.
