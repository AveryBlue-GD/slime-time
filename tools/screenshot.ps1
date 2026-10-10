# Runs the game for a number of frames and saves the last frame to .screens/latest.png,
# so Claude (or you) can look at what the game actually renders.
# Usage: .\tools\screenshot.ps1 [-Frames 30] [-Scene res://scenes/main.tscn] [-Level 5]
# -Level starts on that level without touching the save file.
param(
    [int]$Frames = 30,
    [string]$Scene = "",
    [int]$Level = 0
)
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root ".screens"
Remove-Item -Recurse -Force $out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $out | Out-Null

$godotArgs = @("--path", $root, "--write-movie", (Join-Path $out "frame.png"), "--fixed-fps", "60", "--quit-after", $Frames)
if ($Scene) { $godotArgs += $Scene }
if ($Level -gt 0) { $godotArgs += @("--", "--level=$Level") }
& (Join-Path $PSScriptRoot "godot.ps1") @godotArgs

$last = Get-ChildItem $out -Filter "frame*.png" | Sort-Object Name | Select-Object -Last 1
if (-not $last) { Write-Error "No frames were written."; exit 1 }
Copy-Item $last.FullName (Join-Path $out "latest.png")
Get-ChildItem $out -Filter "frame*.png" | Remove-Item
Write-Output "Saved $(Join-Path $out 'latest.png')"
