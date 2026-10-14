# Opens the game for playtesting on the right-most monitor without stealing focus (click the
# window to play), so whatever is in front on the other screen stays there.
# Usage: .\tools\play.ps1 [-Dev | -Story] [-Scene res://tests/demo_record_run.tscn] [-GameArgs --skin=ocean]
#   -Dev      everything unlocked, nothing saved (the --unlock-all debug flag)
#   -Story    the whole story beaten on normal AND hard, all coins found, nothing saved (--story-complete)
#   -Scene    start in a specific scene instead of the title
#   -GameArgs extra debug flags for the game (see scripts/progress.gd)
param(
    [switch]$Dev,
    [switch]$Story,
    [string]$Scene = "",
    [string[]]$GameArgs = @()
)
. (Join-Path $PSScriptRoot "quiet_window.ps1")

$godotArgs = @("--path", $QuietRoot) + (Get-RightScreenArgs)
if ($Scene) { $godotArgs += $Scene }
$userArgs = @("--quiet-window") + @($GameArgs)
if ($Dev) { $userArgs += "--unlock-all" }
if ($Story) { $userArgs += "--story-complete" }
$godotArgs += @("--") + $userArgs

Set-NoFocus
try {
    & (Get-GodotExe) @godotArgs
} finally {
    Remove-NoFocus
}
