# Chạy N trận headless (mặc định 100) giữa hai controller ngẫu nhiên. Cần Godot 4.x (PATH hoặc $env:GODOT_EXE).
param(
    [string]$GodotExe = $env:GODOT_EXE,
    [int]$Matches = 100
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GamePath = Join-Path $ProjectRoot "game"

if (-not $GodotExe) {
    $cmd = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $GodotExe = $cmd.Source }
}

if (-not $GodotExe -or -not (Test-Path $GodotExe)) {
    Write-Error "Khong tim thay Godot. Cai Godot 4.x hoac dat `$env:GODOT_EXE tro toi godot.exe."
    exit 1
}

Write-Host "Using: $GodotExe"
& $GodotExe --headless --path $GamePath --scene res://scenes/headless_matches.tscn -- --matches=$Matches
exit $LASTEXITCODE
