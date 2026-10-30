# Chay N tran headless giua hai controller bat ky (random, rusher, turtle, poker, mirror, rotate).
# Can Godot 4.x (PATH hoac $env:GODOT_EXE).
param(
    [string]$GodotExe = $env:GODOT_EXE,
    [int]$Matches = 100,
    [string]$P1 = "random",
    [string]$P2 = "random",
    [string]$Model = "data/models/mirror.json",
    [int]$Seed = 1,
    [double]$Epsilon = 0.12,
    [double]$Temperature = 0.7,
    [string]$ResultsCsv = "",
    [string]$LogCsv = "",
    [string]$LogSide = "p1",
    [int]$MinRows = 0
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GamePath = Join-Path $ProjectRoot "game"

if (-not $GodotExe) {
    $cmd = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $GodotExe = $cmd.Source }
}

if (-not $GodotExe) {
    $candidates = @(
        "${env:ProgramFiles}\Godot\Godot_v4.3-stable_win64.exe",
        "${env:ProgramFiles}\Godot\Godot_v4.4-stable_win64.exe",
        "${env:LOCALAPPDATA}\Programs\Godot\Godot_v4.3-stable_win64.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $GodotExe = $c; break }
    }
}

if (-not $GodotExe -or -not (Test-Path $GodotExe)) {
    Write-Error "Khong tim thay Godot. Cai Godot 4.x hoac dat `$env:GODOT_EXE tro toi godot.exe."
    exit 1
}

$userArgs = @(
    "--matches=$Matches",
    "--p1=$P1",
    "--p2=$P2",
    "--model=$Model",
    "--seed=$Seed",
    "--epsilon=$Epsilon",
    "--temperature=$Temperature",
    "--log-side=$LogSide"
)
if ($ResultsCsv -ne "") { $userArgs += "--results-csv=$ResultsCsv" }
if ($LogCsv -ne "") { $userArgs += "--log-csv=$LogCsv" }
if ($MinRows -gt 0) { $userArgs += "--min-rows=$MinRows" }

Write-Host "Using: $GodotExe"
& $GodotExe --headless --path $GamePath --scene res://scenes/headless_matches.tscn -- @userArgs
exit $LASTEXITCODE
