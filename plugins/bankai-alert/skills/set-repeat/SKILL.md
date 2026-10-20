---
name: set-repeat
description: Set how many times the bankai-alert plugin plays its alert sound (1-50) when Claude asks a question or needs permission, or show the current count. Use when the user wants the alert to repeat more or fewer times, play only once, or ring longer/shorter.
argument-hint: "<times 1-50> | show"
---

# Set how many times the alert repeats

Arguments: `$ARGUMENTS`

The alert plays up to N times and stops early as soon as the user responds. N comes from, in order:
1. The `CLAUDE_ALERT_REPEAT` env var. If it's set, tell the user it overrides the value saved here and where to remove it (shell profile or the `env` block of `~/.claude/settings.json`).
2. A `repeat=N` line in `~/.claude/bankai-alert/config`.
3. The default, 5.

Values are limited to 1-50. If `CLAUDE_ALERT_MAX_SECONDS` is set, it can stop the alert sooner, so mention it if it's set.

## What to do

**`show` or no arguments:** read `~/.claude/bankai-alert/config` and report the current count (5 if there's no `repeat=` line), then show the usage line from `argument-hint`.

**A number:**
1. Check that it's a whole number from 1 to 50. If it isn't, say so and stop. For 0 or "off", explain that the minimum is 1, and that `claude plugin disable bankai-alert@bankai-alert` turns the alerts off.
2. Write `repeat=<N>` to `~/.claude/bankai-alert/config` as plain UTF-8 without a BOM. Use the shell (`printf`) or the Write tool, not PowerShell `Out-File`/`Set-Content`. Create the folder if it's missing. Replace an existing `repeat=` line and keep any other lines.
3. Confirm it in one line, for example "Alert will play 3 times (stops as soon as you respond)". The change applies at the next alert. A restart isn't needed.
