#!/bin/sh
# Cross-platform alert sound for Claude Code hook events.
# Usage: alert.sh <question|notify|stop>
#
# question/notify play the sound up to N times, stopping early when the user
# responds (a "stop" call from the PostToolUse / UserPromptSubmit / Stop hooks).
#
# Settings (env vars win over ~/.claude/bankai-alert/config, which
# /bankai-alert:set-repeat writes as "repeat=N"):
#   CLAUDE_ALERT_REPEAT       how many times to play (default 5, 1-50)
#   CLAUDE_ALERT_MAX_SECONDS  optional time limit; 0 = play once (older setting)
#   CLAUDE_ALERT_GAP_SECONDS  pause between repeats (default 1)
#   CLAUDE_ALERT_QUESTION_WAV / CLAUDE_ALERT_NOTIFY_WAV  custom sound files
#                             (default: ~/.claude/bankai-alert/, then the plugin's sounds/alert.wav)
kind="${1:-notify}"
dir="$(cd "$(dirname "$0")" && pwd)"
userdir="$HOME/.claude/bankai-alert"
max="$CLAUDE_ALERT_MAX_SECONDS"
gap="${CLAUDE_ALERT_GAP_SECONDS:-1}"

repeat="$CLAUDE_ALERT_REPEAT"
[ -z "$repeat" ] && repeat="$(sed -n 's/^[^a-z]*repeat[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p' "$userdir/config" 2>/dev/null | tail -1)"
case "$repeat" in ''|*[!0-9]*) repeat=5 ;; esac
[ "$repeat" -lt 1 ] && repeat=1
[ "$repeat" -gt 50 ] && repeat=50
[ "$max" = "0" ] && repeat=1

# One marker file per session, so parallel sessions don't silence each other.
input="$(cat 2>/dev/null | tr -d '\r\n')"
sid="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
marker="${TMPDIR:-/tmp}/bankai-alert-${sid:-default}.ring"

if [ "$kind" = "stop" ]; then
  rm -f "$marker"
  exit 0
fi

if [ "$kind" = "question" ]; then custom="$CLAUDE_ALERT_QUESTION_WAV"; else custom="$CLAUDE_ALERT_NOTIFY_WAV"; fi
# Sound priority: env var > user's sound from /bankai-alert:set-sound
# (~/.claude/bankai-alert/<kind>.wav, then alert.wav) > the plugin's bundled
# sound > system sound. The user folder survives plugin updates.
for f in "$userdir/$kind.wav" "$userdir/alert.wav" "$dir/../sounds/alert.wav"; do
  [ -n "$custom" ] && break
  [ -f "$f" ] && custom="$f"
done

play() {
  case "$(uname -s)" in
    Darwin)
      if [ "$kind" = "question" ]; then def="/System/Library/Sounds/Glass.aiff"; else def="/System/Library/Sounds/Ping.aiff"; fi
      afplay "${custom:-$def}" >/dev/null 2>&1 || osascript -e 'beep' >/dev/null 2>&1
      ;;
    Linux)
      # WSL: Linux audio is often missing, so use the Windows player.
      if grep -qi microsoft /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$dir/alert.ps1")" "$kind" ${custom:+"$(wslpath -w "$custom")"} >/dev/null 2>&1
        return
      fi
      if [ "$kind" = "question" ]; then def="/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"; else def="/usr/share/sounds/freedesktop/stereo/bell.oga"; fi
      snd="${custom:-$def}"
      { command -v pw-play >/dev/null 2>&1 && pw-play "$snd" >/dev/null 2>&1; } ||
      { command -v paplay  >/dev/null 2>&1 && paplay "$snd" >/dev/null 2>&1; } ||
      { command -v canberra-gtk-play >/dev/null 2>&1 && canberra-gtk-play -f "$snd" >/dev/null 2>&1; } ||
      { command -v aplay   >/dev/null 2>&1 && aplay -q "$snd" >/dev/null 2>&1; } ||
      { printf '\a' > /dev/tty; sleep 1; } 2>/dev/null
      ;;
    MINGW*|MSYS*|CYGWIN*)
      ps1="$dir/alert.ps1"; snd="$custom"
      command -v cygpath >/dev/null 2>&1 && { ps1="$(cygpath -w "$ps1")"; [ -n "$snd" ] && snd="$(cygpath -w "$snd")"; }
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ps1" "$kind" ${snd:+"$snd"} >/dev/null 2>&1
      ;;
    *)
      printf '\a' > /dev/tty 2>/dev/null
      ;;
  esac
}

# The marker holds "<pid> <last heartbeat>". If another alert is already
# ringing for this session (e.g. AskUserQuestion also fires a permission_prompt
# notification), keep it going. No heartbeat for 60s means its loop was killed.
if [ -s "$marker" ]; then
  beat="$(cut -d' ' -f2 "$marker" 2>/dev/null)"
  case "$beat" in ''|*[!0-9]*) beat=0 ;; esac
  [ $(( $(date +%s) - beat )) -lt 60 ] && exit 0
fi

# Claim the marker; "stop" removes it and this loop exits.
printf '%s %s' "$$" "$(date +%s)" > "$marker"
start="$(date +%s)"
played=0

while :; do
  play
  played=$((played + 1))
  [ "$played" -lt "$repeat" ] || break
  sleep "$gap"
  [ "$(cut -d' ' -f1 "$marker" 2>/dev/null)" = "$$" ] || exit 0
  if [ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null; then
    [ $(( $(date +%s) - start )) -lt "$max" ] || break
  fi
  printf '%s %s' "$$" "$(date +%s)" > "$marker"
done

[ "$(cut -d' ' -f1 "$marker" 2>/dev/null)" = "$$" ] && rm -f "$marker"
exit 0
