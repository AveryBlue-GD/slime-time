# Renders the itch.io cover (630x500) and screenshots (1280x720) from the real game.
# Usage: .\tools\promo\make_promo.ps1 [-OutDir <folder>]   (default: Desktop\SlimeTime-itch-images)
# Uses debug flags (--unlock-all, --skin=...), so the real save file is never touched.
param(
    [string]$OutDir = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'SlimeTime-itch-images')
)
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$shot = Join-Path $root 'tools\screenshot.ps1'
$upscale = Join-Path $root 'tools\upscale_png.py'
New-Item -ItemType Directory -Force $OutDir | Out-Null

function Capture([string]$name, [string]$scene, [int]$frames, [string[]]$gameArgs, [int]$scale) {
    & $shot -Frames $frames -Scene $scene -GameArgs $gameArgs | Out-Null
    python $upscale (Join-Path $root '.screens\latest.png') (Join-Path $OutDir $name) $scale | Out-Null
    Write-Output "wrote $name"
}

# The cover renders itself at 315x250 (its own SubViewport) and saves the PNG directly.
$raw = Join-Path $env:TEMP 'slimetime_cover_raw.png'
$coverArgs = @('--path', $root, '--fixed-fps', '60', 'res://tools/promo/cover.tscn', '--', '--unlock-all', '--skin=ember', "--out=$raw")
& (Join-Path $root 'tools\godot.ps1') @coverArgs | Out-Null
python $upscale $raw (Join-Path $OutDir 'cover.png') 2 | Out-Null
Remove-Item $raw
Write-Output 'wrote cover.png'
Capture 'screenshot-1-title.png' 'res://scenes/title.tscn' 40 @('--unlock-all', '--skin=ember') 4
Capture 'screenshot-2-fog.png' 'res://tests/demo.tscn' 700 @('--unlock-all', '--skin=ember', '--level=3') 4
Capture 'screenshot-3-jump.png' 'res://tools/promo/jump_shot.tscn' 360 @('--unlock-all', '--skin=ocean') 4
Capture 'screenshot-4-rainbow.png' 'res://tests/demo.tscn' 950 @('--unlock-all', '--skin=rainbow', '--random') 4
Capture 'screenshot-5-skins.png' 'res://scenes/skins.tscn' 40 @('--unlock-all', '--skin=custom') 4
