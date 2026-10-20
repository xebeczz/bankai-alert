#!/bin/sh
# Tests alert.sh with stub sound players that log each play instead of making noise.
# Usage: sh tests/run.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/plugins/bankai-alert/scripts/alert.sh"
work="$(mktemp -d)"
export HOME="$work/home"; mkdir -p "$HOME"
export TMPDIR="$work/tmp"; mkdir -p "$TMPDIR"
log="$work/plays.log"
fails=0

# Stub players: record "<player> <file>" and pretend to play for 0.2s.
mkdir -p "$work/bin"
for p in afplay pw-play paplay canberra-gtk-play aplay powershell.exe; do
  printf '#!/bin/sh\necho "%s $*" >> "%s"\nsleep 0.2\n' "$p" "$log" > "$work/bin/$p"
  chmod +x "$work/bin/$p"
done
export PATH="$work/bin:$PATH"
export CLAUDE_ALERT_GAP_SECONDS=0
unset CLAUDE_ALERT_REPEAT CLAUDE_ALERT_MAX_SECONDS CLAUDE_ALERT_QUESTION_WAV CLAUDE_ALERT_NOTIFY_WAV 2>/dev/null

# run <session> <kind> [VAR=value ...] - env vars apply to this run only
# (in macOS /bin/sh, "VAR=x func" leaks VAR into the rest of the script).
run() { sid=$1 kind=$2; shift 2; : > "$log"; echo "{\"session_id\":\"$sid\"}" | env "$@" sh "$script" "$kind"; }
plays() { wc -l < "$log" | tr -d ' '; }
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (expected '$2', got '$3')"; fails=$((fails + 1)); fi
}

echo "OS: $(uname -s) $(uname -r)"
sh -n "$script"; check "script syntax" 0 $?

run s1 question; check "default plays 5 times" 5 "$(plays)"
check "uses bundled alert.wav" 1 "$(grep -cE 'sounds[/\]alert.wav' "$log" | awk '{print ($1>0)}')"

run s2 notify CLAUDE_ALERT_REPEAT=2; check "CLAUDE_ALERT_REPEAT=2" 2 "$(plays)"
run s3 notify CLAUDE_ALERT_MAX_SECONDS=0; check "MAX_SECONDS=0 plays once" 1 "$(plays)"

mkdir -p "$HOME/.claude/bankai-alert"
printf 'repeat=3\n' > "$HOME/.claude/bankai-alert/config"; run s4 question; check "config repeat=3" 3 "$(plays)"
printf '\357\273\277repeat=2\r\n' > "$HOME/.claude/bankai-alert/config"; run s5 question; check "config with BOM+CRLF" 2 "$(plays)"
printf 'repeat=99\n' > "$HOME/.claude/bankai-alert/config"; run s6 question CLAUDE_ALERT_MAX_SECONDS=2
check "repeat capped and time limit stops it" 1 "$( [ "$(plays)" -lt 50 ] && echo 1 || echo 0)"
rm -f "$HOME/.claude/bankai-alert/config"

printf 'x' > "$HOME/.claude/bankai-alert/question.wav"
run s7 question CLAUDE_ALERT_REPEAT=1; check "user question.wav is used" 1 "$(grep -cE 'bankai-alert[/\]question.wav' "$log")"
run s8 notify CLAUDE_ALERT_REPEAT=1; check "notify falls back to bundled" 1 "$(grep -cE 'sounds[/\]alert.wav' "$log")"
run s9 question CLAUDE_ALERT_REPEAT=1 CLAUDE_ALERT_QUESTION_WAV=/env/override.wav; check "env var overrides user file" 1 "$(grep -c 'override.wav' "$log")"
rm -rf "$HOME/.claude/bankai-alert"

# Stop: 20 repeats, stop after ~1s.
: > "$log"; echo '{"session_id":"st"}' | CLAUDE_ALERT_REPEAT=20 sh "$script" question & pid=$!
sleep 1; echo '{"session_id":"st"}' | sh "$script" stop; wait $pid
check "stop ends the alert early" 1 "$( [ "$(plays)" -lt 20 ] && echo 1 || echo 0)"

# Overlap: a second alert while one is ringing exits without playing.
: > "$log"; echo '{"session_id":"ov"}' | CLAUDE_ALERT_REPEAT=4 sh "$script" question & pid=$!
sleep 0.3; echo '{"session_id":"ov"}' | sh "$script" notify; wait $pid
check "overlapping alert doesn't double up" 4 "$(plays)"

check "no marker files left" 0 "$(ls "$TMPDIR"/bankai-alert-* 2>/dev/null | wc -l | tr -d ' ')"

rm -rf "$work"
echo "---"; [ "$fails" -eq 0 ] && echo "ALL PASSED" || echo "$fails FAILED"
exit "$fails"
