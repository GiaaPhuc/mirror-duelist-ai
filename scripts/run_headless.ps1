# Smoke test Godot headless (Windows). Cài Godot 4.x và thêm vào PATH hoặc đặt biến GODOT_EXE.
param(
    [string]$GodotExe = $env:GODOT_EXE
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GamePath = Join-Path $ProjectRoot "game"

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
    Write-Error "Không tìm thấy Godot. Cài Godot 4.x hoặc đặt `$env:GODOT_EXE đường dẫn tới godot.exe."
    exit 1
}

Write-Host "Using: $GodotExe"
& $GodotExe --headless --path $GamePath --scene res://scenes/headless_test.tscn
exit $LASTEXITCODE
