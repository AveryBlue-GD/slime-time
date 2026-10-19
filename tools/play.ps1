# Opens the game for playtesting on the right-most monitor without stealing focus (click the
# window to play), so whatever is in front on the other screen stays there.
# Usage: .\tools\play.ps1 [-Dev | -Story | -Demo | -Autoplay [-Speed 3]] [-Scene res://tests/demo_record_run.tscn] [-GameArgs --skin=ocean]
#   -Dev      everything unlocked, nothing saved (the --unlock-all debug flag)
#   -Story    the whole story beaten on normal AND hard, all coins found, nothing saved (--story-complete)
#   -Autoplay the game plays the whole story by itself (every coin, upgrades, medals, then hard mode)
#             from a fresh in-memory state, nothing saved (--autoplay); -Speed N = N x real time (default 3,
#             1-8); -Cinematics also plays the story intro/finale. F10 or Esc -> QUIT TO HUB stops it.
#   -Demo     the demo build (docs/demo-plan.md) on a clean in-memory save, nothing saved (--demo; add
#             -GameArgs --save-path=user://demo_try.cfg to keep a separate save and try the carry-over)
#   -Scene    start in a specific scene instead of the title
#   -GameArgs extra debug flags for the game (see scripts/progress.gd)
param(
    [switch]$Dev,
    [switch]$Story,
    [switch]$Autoplay,
    [switch]$Demo,
    [double]$Speed = 0,
    [switch]$Cinematics,
    [string]$Scene = "",
    [string[]]$GameArgs = @()
)
. (Join-Path $PSScriptRoot "quiet_window.ps1")

$godotArgs = @("--path", $QuietRoot) + (Get-RightScreenArgs)
if ($Scene) { $godotArgs += $Scene }
$userArgs = @("--quiet-window") + @($GameArgs)
if ($Dev) { $userArgs += "--unlock-all" }
if ($Story) { $userArgs += "--story-complete" }
if ($Demo) { $userArgs += "--demo" }
if ($Autoplay) { $userArgs += "--autoplay" }
if ($Autoplay -and $Speed -gt 0) { $userArgs += "--speed=" + $Speed.ToString([Globalization.CultureInfo]::InvariantCulture) }
if ($Autoplay -and $Cinematics) { $userArgs += "--autoplay-cinematics" }
$godotArgs += @("--") + $userArgs

Set-NoFocus
try {
    & (Get-GodotExe) @godotArgs
} finally {
    Remove-NoFocus
}
