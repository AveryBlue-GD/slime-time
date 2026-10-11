# Runs the game for a number of frames and saves the last frame to .screens/latest.png,
# so Claude (or you) can look at what the game actually renders.
# Usage: .\tools\screenshot.ps1 [-Frames 30] [-Scene res://scenes/main.tscn] [-Level 5] [-GameArgs --unlock-all,--skin=custom]
# -Level / -GameArgs are passed to the game as debug flags (see scripts/progress.gd); they never touch the save file.
# The capture window opens on the right-most monitor without taking focus (see quiet_window.ps1).
param(
    [int]$Frames = 30,
    [string]$Scene = "",
    [int]$Level = 0,
    [string[]]$GameArgs = @()
)
. (Join-Path $PSScriptRoot "quiet_window.ps1")
$root = $QuietRoot
$out = Join-Path $root ".screens"
Remove-Item -Recurse -Force $out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $out | Out-Null

$godotArgs = @("--path", $root, "--write-movie", (Join-Path $out "frame.png"), "--fixed-fps", "60", "--quit-after", $Frames) + (Get-RightScreenArgs)
if ($Scene) { $godotArgs += $Scene }
$userArgs = @("--quiet-window") + @($GameArgs)
if ($Level -gt 0) { $userArgs += "--level=$Level" }
$godotArgs += @("--") + $userArgs
Set-NoFocus
try {
    & (Get-GodotExe) @godotArgs
} finally {
    Remove-NoFocus
}

$last = Get-ChildItem $out -Filter "frame*.png" | Sort-Object Name | Select-Object -Last 1
if (-not $last) { Write-Error "No frames were written."; exit 1 }
Copy-Item $last.FullName (Join-Path $out "latest.png")
Get-ChildItem $out -Filter "frame*.png" | Remove-Item
Write-Output "Saved $(Join-Path $out 'latest.png')"
