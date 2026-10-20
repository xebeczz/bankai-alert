# Plays an alert sound for Claude Code hook events.
# Usage: alert.ps1 <question|notify> [path-to-wav]
# Sound priority: path argument > CLAUDE_ALERT_QUESTION_WAV / CLAUDE_ALERT_NOTIFY_WAV
#                 > bundled sounds\alert.wav > Windows system sound.
param([string]$Kind = "notify", [string]$Wav = "")

if (-not $Wav) {
    if ($Kind -eq "question") { $Wav = $env:CLAUDE_ALERT_QUESTION_WAV } else { $Wav = $env:CLAUDE_ALERT_NOTIFY_WAV }
}
if (-not $Wav) {
    $bundled = Join-Path $PSScriptRoot "..\sounds\alert.wav"
    if (Test-Path $bundled) { $Wav = $bundled }
}
if (-not $Wav) {
    $media = Join-Path $env:WINDIR "Media"
    if ($Kind -eq "question") { $Wav = Join-Path $media "Windows Notify System Generic.wav" } else { $Wav = Join-Path $media "Windows Exclamation.wav" }
}

try {
    if (Test-Path $Wav) {
        (New-Object System.Media.SoundPlayer $Wav).PlaySync()
    } else {
        [System.Media.SystemSounds]::Exclamation.Play()
        Start-Sleep -Milliseconds 800
    }
} catch {
    [console]::beep(880, 300)
}
exit 0
