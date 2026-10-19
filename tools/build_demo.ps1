# Builds and VERIFIES the demo exports in one go (docs/demo-plan.md "Shipping the demo"; twin: build_demo.sh).
#   .\tools\build_demo.ps1 [-All] [-NoSmoke]
# 0. self-tests tools/pck_check.py (tools/test_pck_check.py: synthetic packs);
# 1. rewrites the demo presets in export_presets.cfg from their full twins + Demo.export_cut()
#    (tools/demo_paths.gd --write-presets; the full presets stay byte-identical);
# 2. exports "Windows Demo" -> build/demo/windows/DryTryingDemo.exe and "Web Demo" -> build/demo/web/index.html
#    (-All: also "Linux Demo"; "macOS Demo" exports on a Mac only, code signing needs Xcode's tools);
# 3. lists every exported pack (tools/pck_check.py) and FAILS if any cut file is inside in any form;
# 4. smoke-runs the Windows and Web packs with the editor binary (--main-pack, never the exported exe itself):
#    tools/demo_smoke.gd plays the demo's levels, the first demo maze and opens every menu on a throwaway
#    save outside the game's user folder (build/demo/reports/demo_smoke_selftest.cfg, deleted afterwards); the
#    web pack runs with --platform=web --expect=web (the web knobs and cut list); the real save is checked
#    unchanged; FAILS on a failed check or any ERROR / SCRIPT ERROR line in its log.
# Reports go to build/demo/reports/ (not inside build/demo/web: that folder's files are the itch upload).
param(
    [switch]$All,
    [switch]$NoSmoke
)
$ErrorActionPreference = "Continue"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godot = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if ($env:GODOT) { $godotExe = $env:GODOT } elseif ($godot) { $godotExe = $godot.FullName } else {
    Write-Error "Godot console executable not found (set GODOT or: winget install GodotEngine.GodotEngine)"; exit 1 }
$reports = Join-Path $root "build\demo\reports"
New-Item -ItemType Directory -Force $reports | Out-Null
$script:status = 0
function Fail([string]$msg) { Write-Output "FAIL: $msg"; $script:status = 1 }
function Label([string]$name) { $name -replace ' ', '_' }

# The player's real save (never written by any of this): its hash before and after.
$realSave = Join-Path $env:APPDATA "SlimeTime_R1\save.cfg"
$saveBefore = if (Test-Path $realSave) { (Get-FileHash $realSave -Algorithm MD5).Hash } else { "" }

Write-Output "== 0. pck_check self-test"
& python (Join-Path $root "tools\test_pck_check.py")
if ($LASTEXITCODE -ne 0) { Fail "the tools/pck_check.py self-test" }

Write-Output "== 1. demo presets"
$out = & $godotExe --path $root --headless -s res://tools/demo_paths.gd -- --write-presets 2>&1
if ($LASTEXITCODE -ne 0) { $out | Select-Object -Last 5; Fail "the demo presets could not be written" }
else { $out | Select-String "demo presets" | ForEach-Object { $_.Line } }
$cutList = Join-Path $reports "cut_list.txt"
Remove-Item -Force $cutList -ErrorAction SilentlyContinue  # never check against a stale list
& $godotExe --path $root --headless -s res://tools/demo_paths.gd -- "--cut-list=$($cutList -replace '\\', '/')" *> $null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $cutList) -or (Get-Item $cutList).Length -eq 0) {
    Remove-Item -Force $cutList -ErrorAction SilentlyContinue
    Fail "the cut list could not be written"
}

$targets = @(
    @{ name = "Windows Demo"; out = "build/demo/windows/DryTryingDemo.exe"; pack = "build/demo/windows/DryTryingDemo.exe"; kind = "desktop"; smoke = $true },
    @{ name = "Web Demo"; out = "build/demo/web/index.html"; pack = "build/demo/web/index.pck"; kind = "web"; smoke = $true }
)
if ($All) {
    $targets += @{ name = "Linux Demo"; out = "build/demo/linux/DryTryingDemo.x86_64"; pack = "build/demo/linux/DryTryingDemo.x86_64"; kind = "desktop"; smoke = $false }
    Write-Output "(macOS Demo: skipped here, it exports on a Mac only - code signing needs Xcode's tools)"
}

Write-Output "== 2. export"
foreach ($t in $targets) {
    $dir = Split-Path (Join-Path $root $t.out)
    Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $dir | Out-Null
    $log = Join-Path $reports "export_$(Label $t.name).log"
    & $godotExe --path $root --headless --export-release $t.name (Join-Path $root $t.out) *> $log
    if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $root $t.out))) {
        Write-Output ("exported {0} -> {1} ({2:N1} MB)" -f $t.name, $t.out, ((Get-Item (Join-Path $root $t.out)).Length / 1MB))
    } else { Fail "export of $($t.name) (see $log)" }
}

Write-Output "== 3. pack contents"
foreach ($t in $targets) {
    $pack = Join-Path $root $t.pack
    if (-not (Test-Path $pack)) { continue }
    & python (Join-Path $root "tools\pck_check.py") $pack --cut-list $cutList --kind $t.kind --list (Join-Path $reports "pack_$(Label $t.name).txt")
    if ($LASTEXITCODE -ne 0) { Fail "$($t.name): the pack check" }
}

if (-not $NoSmoke) {
    Write-Output "== 4. smoke run of the exported packs (editor binary + --main-pack, throwaway save)"
    $smokeScript = (Join-Path $root "tools\demo_smoke.gd") -replace '\\', '/'
    foreach ($t in $targets) {
        if (-not $t.smoke) { continue }
        $pack = Join-Path $root $t.pack
        if (-not (Test-Path $pack)) { continue }
        $log = Join-Path $reports "smoke_$(Label $t.name).log"
        $save = Join-Path $reports "demo_smoke_selftest.cfg"
        Remove-Item -Force $save, "$save.tmp" -ErrorAction SilentlyContinue
        $smokeArgs = @("--save-path=$($save -replace '\\', '/')", "--expect=$($t.kind)")
        if ($t.kind -eq "web") { $smokeArgs += "--platform=web" }
        Push-Location $reports
        & $godotExe --headless --fixed-fps 60 --quit-after 200000 --main-pack ($pack -replace '\\', '/') -s $smokeScript -- @smokeArgs *> $log
        $code = $LASTEXITCODE
        Pop-Location
        if ((Test-Path $save) -or (Test-Path "$save.tmp")) {
            Write-Output "(the smoke run left its throwaway save behind: $save - deleted)"
            Remove-Item -Force $save, "$save.tmp" -ErrorAction SilentlyContinue
        }
        $text = Get-Content $log
        $errors = $text | Where-Object { $_ -match '^(ERROR|SCRIPT ERROR|USER ERROR)' -and $_ -notmatch 'still in use at exit' }
        $checks = ($text | Where-Object { $_ -match '^  ok' }).Count
        if ($code -eq 0 -and ($text -match '^RESULT: PASS') -and -not $errors) {
            Write-Output "$($t.name): smoke PASS ($checks checks; log $log)"
        } else {
            $text | Where-Object { $_ -match 'FAIL|^(ERROR|SCRIPT ERROR|USER ERROR)' } | Select-Object -First 20
            Fail "$($t.name): smoke run (exit $code; log $log)"
        }
    }
}

if ($saveBefore -ne "" -and (Get-FileHash $realSave -Algorithm MD5).Hash -ne $saveBefore) { Fail "the real save changed: $realSave" }

Write-Output "== report"
$cut = Get-Content $cutList | Where-Object { $_ -like "desktop`t*" }
Write-Output ("cut list: {0} paths for desktop ({1} files + their .import), see {2}" -f $cut.Count, ($cut | Where-Object { $_ -notlike "*.import" }).Count, $cutList)
foreach ($t in $targets) {
    $file = Join-Path $root $t.out
    if (Test-Path $file) {
        $line = "{0}: {1} {2:N1} MB" -f $t.name, $t.out, ((Get-Item $file).Length / 1MB)
        if ($t.pack -ne $t.out -and (Test-Path (Join-Path $root $t.pack))) { $line += ", pack {0:N1} MB" -f ((Get-Item (Join-Path $root $t.pack)).Length / 1MB) }
        Write-Output $line
    }
}
if ($script:status -eq 0) { Write-Output "DEMO BUILD: PASS" } else { Write-Output "DEMO BUILD: FAIL" }
exit $script:status
