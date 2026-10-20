---
name: set-sound
description: Change the bankai-alert plugin's alert sound to the user's own audio file (any format), set separate sounds for questions vs permission prompts, list the current sound, or reset to the default. Use when the user wants a different or custom alert/notification sound for Claude Code.
argument-hint: "<path-to-audio-file> [question|notify] | reset | show"
---

# Set the alert sound

Arguments: `$ARGUMENTS`

The alert script picks the first sound file that exists, in this order:
1. Env vars `CLAUDE_ALERT_QUESTION_WAV` / `CLAUDE_ALERT_NOTIFY_WAV`. If either is set, tell the user it overrides anything set here.
2. `~/.claude/bankai-alert/question.wav` (AskUserQuestion) or `~/.claude/bankai-alert/notify.wav` (permission/idle prompts).
3. `~/.claude/bankai-alert/alert.wav` (both kinds).
4. The plugin's bundled `sounds/alert.wav`.

`~/.claude/bankai-alert/` is outside the plugin, so it survives plugin updates.

## What to do

**`show` or no arguments:** list the files in `~/.claude/bankai-alert/` and say which sound is active for questions and which for notifications. If there are none, the bundled sound is active. Then show the usage line from `argument-hint`.

**`reset`:** after confirming with the user, delete `question.wav`, `notify.wav` and `alert.wav` from `~/.claude/bankai-alert/`. The bundled sound becomes active again.

**`<file> [question|notify]`:**
1. Check that the file exists. The target name is `question.wav` or `notify.wav` if the user gave a kind, otherwise `alert.wav`.
2. Convert the file to **16-bit PCM WAV, mono** at `~/.claude/bankai-alert/<target>`. Windows can only play this format, so do the conversion even if the file is already a `.wav`. Create the folder if it's missing.
   - If `ffmpeg` is available: `ffmpeg -y -i "<file>" -ac 1 -ar 22050 -c:a pcm_s16le "<target>"`
   - Otherwise on macOS: `afconvert -f WAVE -d LEI16@22050 -c 1 "<file>" "<target>"`
   - Otherwise: ask the user to install ffmpeg (`winget install Gyan.FFmpeg`, `brew install ffmpeg`, or `sudo apt install ffmpeg`). Don't copy an unconverted file.
3. If the sound is longer than 5 seconds, tell the user it repeats until they respond, so a short clip works better. Offer to trim it with `-t 3` added to the ffmpeg command.
4. Play it once to test: `CLAUDE_ALERT_MAX_SECONDS=0 sh "${CLAUDE_PLUGIN_ROOT}/scripts/alert.sh" <question|notify> < /dev/null`
5. Say it's set and takes effect at the next alert. A restart isn't needed.
