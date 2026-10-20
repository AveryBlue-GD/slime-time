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

# Every shot puts each level's own skin on it (the one its first run equips: Lime 1, Mint 2,
# Lemon 3, Ocean 4, Grape 5, Crimson 6, Frost 7, Inkky 8, Bubblegum 9, Ember 10). The RAINBOW and
# STOPWATCH skins are never shown in colour in promo material (owner, 2026-10-20; cover.gd falls
# back to the level's skin if asked). The rainbow HAT is fine.

# The cover renders itself at 315x250 (its own SubViewport) and saves the PNG directly: the
# Frozen Fortress, a Frost slime well into the maze with its light maxed out.
$raw = Join-Path $env:TEMP 'slimetime_cover_raw.png'
$coverArgs = @('--path', $root, '--fixed-fps', '60') + (Get-RightScreenArgs 315 250) + @(
    'res://tools/promo/cover.tscn', '--', '--quiet-window', '--unlock-all', '--skin=frost', '--upgrades=0,0,3',
    '--cover-level=7', '--cover-frame=1300', "--out=$raw")
Set-NoFocus
try { & (Get-GodotExe) @coverArgs | Out-Null } finally { Remove-NoFocus }
python $upscale $raw (Join-Path $OutDir 'cover.png') 2 | Out-Null
Remove-Item $raw
Write-Output 'wrote cover.png'

Capture 'screenshot-1-title.png' 'res://scenes/title.tscn' 40 @('--unlock-all', '--skin=lime')
Capture 'screenshot-2-sunken-shrine.png' 'res://tests/demo.tscn' 900 @('--unlock-all', '--skin=ocean', '--level=4', '--upgrades=0,0,2', '--coins=14')
Capture 'screenshot-3-charged-leap.png' 'res://tools/promo/jump_shot.tscn' 360 @('--unlock-all', '--skin=mint', '--coins=6')  # level 2, the Mossy Mines
Capture 'screenshot-4-volcanic-vault.png' 'res://tests/demo.tscn' 1100 @('--unlock-all', '--skin=ember', '--level=10', '--upgrades=0,0,2', '--coins=37')
Capture 'screenshot-5-crystal-caverns.png' 'res://tests/demo.tscn' 1000 @('--unlock-all', '--skin=bubblegum', '--level=9', '--upgrades=0,0,2', '--all-coins')
Capture 'screenshot-6-new-record.png' 'res://tests/demo_record_run.tscn' 1150 @('--unlock-all', '--skin=lemon', '--coins=9')  # level 3, the Sandstone Sanctum; the win lands at about frame 1084 (banner at once, buttons 0.6 s later)
Capture 'screenshot-7-upgrades.png' 'res://scenes/upgrades.tscn' 40 @('--skin=mint', '--upgrades=4,1,2', '--coins=12')
Capture 'screenshot-8-skins.png' 'res://scenes/skins.tscn' 40 @('--unlock-all', '--skin=bubblegum')
