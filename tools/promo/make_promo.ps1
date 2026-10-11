# Renders the itch.io cover (630x500) and screenshots (1280x720) from the real game.
# Usage: .\tools\promo\make_promo.ps1 [-OutDir <folder>]   (default: Desktop\SlimeTime-itch-images)
# Uses debug flags (--unlock-all, --skin=..., --upgrades=...), so the real save file is never
# touched, and opens its windows quietly (right monitor, no focus; see tools/quiet_window.ps1).
param(
    [string]$OutDir = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'SlimeTime-itch-images')
)
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'tools\quiet_window.ps1')
$shot = Join-Path $root 'tools\screenshot.ps1'
$upscale = Join-Path $root 'tools\upscale_png.py'
New-Item -ItemType Directory -Force $OutDir | Out-Null
Get-ChildItem $OutDir -Filter 'screenshot-*.png' | Remove-Item

function Capture([string]$name, [string]$scene, [int]$frames, [string[]]$gameArgs) {
    & $shot -Frames $frames -Scene $scene -GameArgs $gameArgs | Out-Null
    python $upscale (Join-Path $root '.screens\latest.png') (Join-Path $OutDir $name) 4 | Out-Null
    Write-Output "wrote $name"
}

# The cover renders itself at 315x250 (its own SubViewport) and saves the PNG directly: the
# Frozen Fortress, an orange slime well into the maze with its light maxed out.
$raw = Join-Path $env:TEMP 'slimetime_cover_raw.png'
$coverArgs = @('--path', $root, '--fixed-fps', '60') + (Get-RightScreenArgs 315 250) + @(
    'res://tools/promo/cover.tscn', '--', '--quiet-window', '--unlock-all', '--skin=ember', '--upgrades=0,0,10',
    '--cover-level=7', '--cover-frame=1300', "--out=$raw")
Set-NoFocus
try { & (Get-GodotExe) @coverArgs | Out-Null } finally { Remove-NoFocus }
python $upscale $raw (Join-Path $OutDir 'cover.png') 2 | Out-Null
Remove-Item $raw
Write-Output 'wrote cover.png'

Capture 'screenshot-1-title.png' 'res://scenes/title.tscn' 40 @('--unlock-all', '--skin=lime')
Capture 'screenshot-2-sunken-shrine.png' 'res://tests/demo.tscn' 900 @('--unlock-all', '--skin=lemon', '--level=4', '--upgrades=0,0,8', '--coins=14')
Capture 'screenshot-3-charged-leap.png' 'res://tools/promo/jump_shot.tscn' 360 @('--unlock-all', '--skin=ocean', '--coins=6')
Capture 'screenshot-4-volcanic-vault.png' 'res://tests/demo.tscn' 1100 @('--unlock-all', '--skin=lime', '--level=10', '--upgrades=0,0,8', '--coins=37')
Capture 'screenshot-5-crystal-rainbow.png' 'res://tests/demo.tscn' 1000 @('--unlock-all', '--skin=rainbow', '--level=9', '--upgrades=0,0,6', '--coins=29')
Capture 'screenshot-6-new-record.png' 'res://tests/demo_record_run.tscn' 1050 @('--unlock-all', '--skin=grape', '--coins=9')
Capture 'screenshot-7-upgrades.png' 'res://scenes/upgrades.tscn' 40 @('--skin=mint', '--upgrades=6,4,7', '--coins=12')
Capture 'screenshot-8-skins.png' 'res://scenes/skins.tscn' 40 @('--unlock-all', '--skin=bubblegum')
