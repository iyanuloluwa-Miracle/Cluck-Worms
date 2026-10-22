
# Run the game-rule, lifecycle, tutorial, natural-play and audio checks.
param([string]$Godot = $env:GODOT)
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    Write-Error "Pass -Godot with the path to the Godot 4.7 console executable."
    exit 2
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$logRoot = Join-Path $projectRoot 'docs\test-results'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$importLog = & $Godot --headless --path $projectRoot --import 2>&1 | Out-String -Width 400
$importExit = $LASTEXITCODE
$importLog | Set-Content -LiteralPath (Join-Path $logRoot 'import.log') -Encoding UTF8
if ($importExit -ne 0 -or $importLog -match 'SCRIPT ERROR|Parse Error') {
    Write-Host $importLog
    exit 1
}
$suites = @(
    @{Name='core'; Args=@('res://tests/TestRunner.tscn')},
    @{Name='chain'; Args=@('res://tests/ChainTestRunner.tscn')},
    @{Name='flow'; Args=@('res://tests/GameFlowTestRunner.tscn')},
    @{Name='scenes'; Args=@('res://tests/SmokeTestRunner.tscn')},
    @{Name='guide'; Args=@('res://tests/GuideTestRunner.tscn')},
    @{Name='arcade-session'; Args=@('res://tests/ArcadeSessionTestRunner.tscn')},
    @{Name='meta'; Args=@('--script','res://tests/run_meta_tests.gd')},
    @{Name='music'; Args=@('--script','res://tests/bench_music.gd')}
)
$failed = 0
foreach ($suite in $suites) {
    $suiteArgs = $suite.Args
    $output = & $Godot --headless --path $projectRoot @suiteArgs 2>&1 | Out-String -Width 400
    $suiteExit = $LASTEXITCODE
    $output | Set-Content -LiteralPath (Join-Path $logRoot ($suite.Name + '.log')) -Encoding UTF8
    $output -split "`r?`n" | Where-Object { $_ -match 'OK |FAIL|PASSED|FAILED|ERROR|SESSION' -and $_ -notmatch '^\s*at:|CategoryInfo|FullyQualified|^\+' } | ForEach-Object { Write-Host $_ }
    if ($suiteExit -ne 0 -or $output -match '(?m)^\s*FAIL\b|SCRIPT ERROR|Parse Error|ERROR:|\btests: \d+ FAILED\b|SMOKE TEST FAILED') { $failed++ }
    Write-Host ($suite.Name + ': exit ' + $suiteExit)
}
if ($failed -gt 0) { Write-Host "$failed suite(s) failed"; exit 1 }
Write-Host 'All eight suites passed. Logs: docs/test-results'
