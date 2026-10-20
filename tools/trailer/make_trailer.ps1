# Renders the vertical trailer drafts (tools/trailer/trailer.json) into build/trailer/:
# short_<ID>.mp4, short_<ID>_sheet.png (contact sheet) and README.md. See docs/marketing/trailer.md.
# Usage: .\tools\trailer\make_trailer.ps1 [-Drafts A,B] [-Force] [-OnlyTakes]
# Godot's windows open quietly on the right-most monitor without focus (tools/quiet_window.ps1); the
# movie writer records the game's audio into the file without playing it. Never touches the save.
# ffmpeg: $env:FFMPEG, PATH, or the winget Gyan.FFmpeg install.
param(
    [string[]]$Drafts = @(),
    [switch]$Force,
    [switch]$OnlyTakes
)
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'tools\quiet_window.ps1')
$take = (Get-RightScreenArgs 320 180)[1]
$pyArgs = @((Join-Path $PSScriptRoot 'trailer.py'), '--godot', (Get-GodotExe), '--quiet', '--pos-take', $take)
if ($Drafts.Count -gt 0) { $pyArgs += @('--drafts', ($Drafts -join ',')) }
if ($Force) { $pyArgs += '--force' }
if ($OnlyTakes) { $pyArgs += '--only-takes' }
try {
    python @pyArgs
} finally {
    Remove-NoFocus
}
exit $LASTEXITCODE
