# Mirror Duelist

Game đối kháng 2D: AI học phong cách chiến đấu của người chơi (Behavior Cloning).

- **Đặc tả:** [SPEC.md](SPEC.md)
- **Kế hoạch 10 tuần:** [Mirror-Duelist-Implementation-Plan.md](Mirror-Duelist-Implementation-Plan.md)

## Chạy game (Godot Editor)

1. Cài [Godot 4.3+](https://godotengine.org/download).
2. Mở thư mục `game/` bằng Godot (Import project).
3. Nhấn **F5** (main scene: `scenes/main.tscn`).

## Chạy headless (smoke test)

```powershell
# Từ root repo (sau khi cài Godot):
$env:GODOT_EXE = "C:\path\to\Godot_v4.x-stable_win64.exe"
.\scripts\run_headless.ps1
```

Hoặc trực tiếp:

```text
godot --headless --path game --scene res://scenes/headless_test.tscn
```

Kết quả mong đợi: in `HEADLESS_OK` và thoát mã 0.

## Cấu trúc thư mục

```text
mirror-duelist-ai/
├── SPEC.md
├── game/                 # Godot project
├── ml/                   # PyTorch (từ Tuần 4+)
├── data/raw, data/models
├── results/
└── report/
```
