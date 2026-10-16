# Runs every automated Cluck & Worms suite headlessly.
# Usage:  $env:GODOT = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"; .\tools\run_tests.ps1
param([string]$Godot = $env:GODOT)

if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "Set `$env:GODOT (or pass -Godot) to a Godot 4.7 console executable."
    exit 2
}

$root = Split-Path -Parent $PSScriptRoot
$suites = @(
    "res://tests/TestRunner.tscn",
    "res://tests/ChainTestRunner.tscn",
    "res://tests/GameFlowTestRunner.tscn",
    "res://tests/SmokeTestRunner.tscn"
)
$failed = 0

& $Godot --headless --path $root --import 2>&1 | Out-Null

foreach ($suite in $suites) {
    Write-Host "=== $suite" -ForegroundColor Cyan
    $out = & $Godot --headless --path $root $suite 2>&1 | Out-String -Width 400
    $lines = $out -split "`r?`n" | Where-Object { $_ -match "OK |FAIL|PASSED|FAILED|ERROR|SCRIPT" -and $_ -notmatch "^\s*at:|CategoryInfo|FullyQualified|^\+" }
    $lines | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0 -or $out -match "FAIL|SCRIPT ERROR|Parse Error") { $failed++ }
}

foreach ($script in "res://tests/run_meta_tests.gd", "res://tests/bench_music.gd") {
    Write-Host "=== $script" -ForegroundColor Cyan
    & $Godot --headless --path $root --script $script 2>&1 | Out-String -Width 400 -Stream |
        Select-String "OK |FAIL|PASSED" | ForEach-Object { Write-Host $_.Line }
    if ($LASTEXITCODE -ne 0) { $failed++ }
}

if ($failed -gt 0) { Write-Host "$failed suite(s) failed" -ForegroundColor Red; exit 1 }
Write-Host "All suites passed" -ForegroundColor Green
