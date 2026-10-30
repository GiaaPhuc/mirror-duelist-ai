# Smoke test toan pipeline Tuan 3:
# 1. Sinh >= 1000 dong du lieu tu BotRusher (qua Godot headless neu co Godot, hoac Python fallback)
# 2. Huan luyen MLP (ml/train.py) -> xuat data/models/mirror.json va data/models/test_vectors.json (ml/export_json.py)
# 3. Kiem tra do khop GDScript vs PyTorch/Python (< 1e-4) va chay thu MirrorController.
param(
    [string]$GodotExe = $env:GODOT_EXE,
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
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

Push-Location $ProjectRoot
try {
    if ($GodotExe -and (Test-Path $GodotExe)) {
        Write-Host "[Week 3 Smoke Test] Running with Godot Headless: $GodotExe"
        & $GodotExe --headless --path $GamePath --scene res://scenes/headless_matches.tscn -- `
            --p1=rusher --p2=rotate --matches=30 --min-rows=1000 `
            --log-csv=data/raw/rusher.csv --results-csv=data/raw/matches.csv
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $PythonExe ml/train.py --data data/raw/rusher.csv --out-model data/models/mirror.json --out-ckpt data/models/best.pt --out-vectors data/models/test_vectors.json
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $PythonExe ml/export_json.py --checkpoint data/models/best.pt --output data/models/mirror.json --test-vectors data/models/test_vectors.json
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $GodotExe --headless --path $GamePath --scene res://scenes/headless_parity_test.tscn -- `
            --model=data/models/mirror.json --vectors=data/models/test_vectors.json
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        Write-Host "[Week 3 Smoke Test] Running 500 bot-vs-bot matches (rusher vs rotate)..."
        & $GodotExe --headless --path $GamePath --scene res://scenes/headless_matches.tscn -- `
            --p1=rusher --p2=rotate --matches=500 --results-csv=data/raw/bot_500_matches.csv
        exit $LASTEXITCODE
    }
    else {
        Write-Host "[Week 3 Smoke Test] Godot CLI not found - running Python smoke test and parity check (ml/smoke_test.py)..."
        & $PythonExe ml/smoke_test.py
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
