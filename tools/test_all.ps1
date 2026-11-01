# Windows twin of tools/test_all.sh: runs every tests/test_*.gd suite headless, in parallel, and reports which failed.
# Usage: .\tools\test_all.ps1 [-Jobs N] [-Times] [-KeepLogs dir] [-JobTimeout sec] [suite_name ...]
#   -Jobs N          parallel jobs (default: 3/4 of the logical processors, at least 2; 1 = one at a time)
#   suite names      only those suites (test_coins ...); default = all of them
#   -Times           print every job's wall time, slowest first
#   -KeepLogs dir    keep each job's full output in dir\<job>.log
#   -JobTimeout sec  wall-clock limit per job (default 600); a job over it is killed (with its child processes) and fails the run
# A job PASSES when its log has "RESULT: PASS" and no "SCRIPT ERROR" / "USER ERROR" line (BUG4-11). The save fuzz's engine
# 'Condition "err != 1"' blocks are collapsed into one count line (BUG4-16). Every suite uses its own per-process throwaway
# save (tests/suite_base.gd), so the jobs cannot disturb each other or the real save.
[CmdletBinding(PositionalBinding = $false)]
param(
    [int]$Jobs = 0,
    [switch]$Times,
    [string]$KeepLogs = "",
    [int]$JobTimeout = 600,
    [Parameter(ValueFromRemainingArguments = $true)] [string[]]$Suites = @()
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godotExe = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $godotExe) { Write-Error "Godot console executable not found. Install with: winget install GodotEngine.GodotEngine"; exit 1 }
if ($Jobs -le 0) { $Jobs = [Math]::Max(2, [int]([Environment]::ProcessorCount * 3 / 4)) }
$wanted = @($Suites | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) })

# Sharded suites (same as test_all.sh): "suite|label|arguments after --". Longest first.
$shards = @(
    "test_nav_fuzz|test_nav_fuzz#scripted|--nav-only=scripted --nav-no-web-child",
    "test_nav_fuzz|test_nav_fuzz#web-ring|--web-ui --nav-child --nav-only=walks --nav-steps=600 --nav-area-steps=500 --nav-seed=1239",
    "test_nav_fuzz|test_nav_fuzz#walks-0-8|--nav-only=walks --nav-walk=0-8",
    "test_nav_fuzz|test_nav_fuzz#walks-9-end|--nav-only=walks --nav-walk=9-",
    "test_maze_golden|test_maze_golden#0|--shard=0",
    "test_maze_golden|test_maze_golden#1|--shard=1",
    "test_maze_golden|test_maze_golden#2|--shard=2",
    "test_maze_golden|test_maze_golden#3|--shard=3"
)
$slow = @("test_attempt_restarts", "test_descent_runs", "test_save_robust", "test_autoplay", "test_spawn_picker")
$sharded = @("test_nav_fuzz", "test_maze_golden")

$all = @(Get-ChildItem (Join-Path $root "tests") -Filter "test_*.gd" | ForEach-Object { $_.BaseName } | Sort-Object)
foreach ($w in $wanted) { if ($all -notcontains $w) { Write-Host "no such suite: $w"; exit 1 } }
function Wants($s) { return ($wanted.Count -eq 0) -or ($wanted -contains $s) }
$jobList = New-Object System.Collections.ArrayList
foreach ($e in $shards) { $p = $e.Split("|"); if (Wants $p[0]) { [void]$jobList.Add(@{ suite = $p[0]; label = $p[1]; args = $p[2] }) } }
foreach ($s in $slow) { if (Wants $s) { [void]$jobList.Add(@{ suite = $s; label = $s; args = "" }) } }
$total = 0
foreach ($s in $all) {
    if (-not (Wants $s)) { continue }
    $total++
    if (($sharded -contains $s) -or ($slow -contains $s)) { continue }
    [void]$jobList.Add(@{ suite = $s; label = $s; args = "" })
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("slime_test_all_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null

function Start-Job1($job) {
    $file = $job.label.Replace("#", "_")
    $log = Join-Path $work "$file.log"
    $argList = @("--path", "`"$root`"", "--headless", "--fixed-fps", "60", "--quit-after", "300000", "-s", "res://tests/$($job.suite).gd")
    if ($job.args) { $argList += "--"; $argList += $job.args.Split(" ") }
    $p = Start-Process -FilePath $godotExe.FullName -ArgumentList $argList -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError ($log + ".err")
    return @{ job = $job; proc = $p; log = $log; file = $file; start = Get-Date; timedout = $false }
}

$started = Get-Date
$queue = New-Object System.Collections.Queue
foreach ($j in $jobList) { $queue.Enqueue($j) }
$running = New-Object System.Collections.ArrayList
$results = New-Object System.Collections.ArrayList
function Finish($r) {
    $log = $r.log
    $text = ""
    if (Test-Path $log) { $text = [IO.File]::ReadAllText($log) }
    if (Test-Path ($log + ".err")) { $text += [IO.File]::ReadAllText($log + ".err"); Remove-Item ($log + ".err") }
    $lines = $text -split "`r?`n"
    # BUG4-16: collapse the save fuzz's engine 'Condition "err != 1"' blocks (the ERROR line and its indented follow-up lines)
    $kept = New-Object System.Collections.Generic.List[string]
    $noise = 0; $skip = $false
    foreach ($l in $lines) {
        if ($l -match '^ERROR: Condition "err != 1"') { $noise++; $skip = $true; continue }
        if ($skip -and $l -match '^\s') { continue }
        $skip = $false
        $kept.Add($l)
    }
    if ($noise -gt 0) { $kept.Add("(collapsed $noise engine ERROR lines 'Condition err != 1' from the save fuzz)") }
    if ($r.timedout) { $kept.Add("TIMEOUT: $($r.job.label) killed after $JobTimeout s") }
    [IO.File]::WriteAllText($log, ($kept -join "`n"))
    $res = "FAIL"
    if ($r.timedout) { $res = "TIMEOUT" }
    elseif ($text -match "RESULT: PASS") { $res = "PASS" }
    $secs = [int]((Get-Date) - $r.start).TotalSeconds
    [void]$results.Add(@{ result = $res; secs = $secs; label = $r.job.label; log = $log; text = ($kept -join "`n") })
}
try {
    while ($queue.Count -gt 0 -or $running.Count -gt 0) {
        while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) { [void]$running.Add((Start-Job1 $queue.Dequeue())) }
        Start-Sleep -Milliseconds 300
        foreach ($r in @($running)) {
            if ($r.proc.HasExited) { $running.Remove($r); Finish $r }
            elseif (((Get-Date) - $r.start).TotalSeconds -gt $JobTimeout) {
                $r.timedout = $true
                & taskkill /PID $r.proc.Id /T /F | Out-Null  # the job and its child processes only
                $r.proc.WaitForExit(); $running.Remove($r); Finish $r
            }
        }
    }
} finally {
    foreach ($r in @($running)) { try { & taskkill /PID $r.proc.Id /T /F | Out-Null } catch {} }
}

$failedJobs = 0
$failedNames = @()
foreach ($r in $results) {
    $res = $r.result
    if ($res -eq "PASS" -and $r.text -match "SCRIPT ERROR|USER ERROR") {
        Write-Host "$($r.label) PASSED but its log has SCRIPT ERROR / USER ERROR lines:"
        ($r.text -split "`n") | Where-Object { $_ -match "SCRIPT ERROR|USER ERROR" } | Select-Object -First 4 | ForEach-Object { Write-Host $_ }
        $res = "SCRIPTERR"
    }
    if ($res -eq "PASS") { continue }
    $failedJobs++
    $failedNames += ($r.label -split "#")[0]
    Write-Host "$($r.label) $(if ($res -eq 'TIMEOUT') { 'TIMEOUT' } else { 'FAILED' }):"
    ($r.text -split "`n") | Where-Object { $_ -match "FAIL|SCRIPT ERROR|USER ERROR|Parse|TIMEOUT" } | Select-Object -First 8 | ForEach-Object { Write-Host $_ }
}
$failed = @($failedNames | Sort-Object -Unique).Count
if ($Times) {
    Write-Host "--- job wall times, slowest first (jobs: $Jobs)"
    $results | Sort-Object { $_.secs } -Descending | Select-Object -First 20 | ForEach-Object { Write-Host "$($_.result) $($_.secs) $($_.label)" }
}
if ($KeepLogs) {
    New-Item -ItemType Directory -Force -Path $KeepLogs | Out-Null
    Copy-Item (Join-Path $work "*.log") $KeepLogs
}
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
Write-Host "suites: $total failed: $failed ($Jobs jobs, $([int]((Get-Date) - $started).TotalSeconds) s)"
exit $(if ($failedJobs -eq 0) { 0 } else { 1 })
