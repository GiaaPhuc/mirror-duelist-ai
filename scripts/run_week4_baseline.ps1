# Pipeline Tuan 4: Thu thap du lieu (>= 10.000 mau/bot + 15 phien human_self),
# huan luyen 3 model Mirror baseline (Rusher, Turtle, Poker) + Mirror-HumanSelf,
# danh gia Mirror-X vs Bot-X va xuat bao cao + bieu do vao results/.
param(
    [string]$GodotExe = $env:GODOT_EXE,
    [string]$PythonExe = "python",
    [int]$MinRows = 10500,
    [int]$EvalMatches = 100
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
        Write-Host "[Week 4 Baseline] Generating >= $MinRows rows per bot via Godot Headless: $GodotExe"
        $bots = @("rusher", "turtle", "poker")
        $seedIdx = 1
        foreach ($b in $bots) {
            & $GodotExe --headless --path $GamePath --scene res://scenes/headless_matches.tscn -- `
                --p1=$b --p2=rotate --matches=50 --min-rows=$MinRows --seed=$seedIdx `
                --log-csv="data/raw/$b.csv" --results-csv="data/raw/matches_$b.csv"
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            $seedIdx += 10
        }

        & $PythonExe ml/week4_baseline.py --min-rows $MinRows --eval-matches $EvalMatches --reuse-existing
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        foreach ($b in $bots) {
            & $GodotExe --headless --path $GamePath --scene res://scenes/headless_parity_test.tscn -- `
                --model="data/models/mirror_$b.json" --vectors="data/models/test_vectors_$b.json"
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
        exit 0
    }
    else {
        Write-Host "[Week 4 Baseline] Running Python Week 4 pipeline (ml/week4_baseline.py)..."
        & $PythonExe ml/week4_baseline.py --min-rows $MinRows --eval-matches $EvalMatches
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
