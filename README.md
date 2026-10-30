# Mirror Duelist

Game đối kháng 2D: AI học phong cách chiến đấu của người chơi (Behavior Cloning).

- **Đặc tả:** [SPEC.md](SPEC.md)
- **Kế hoạch 10 tuần:** [Mirror-Duelist-Implementation-Plan.md](Mirror-Duelist-Implementation-Plan.md)

## Chạy game (Godot Editor)

1. Cài [Godot 4.3+](https://godotengine.org/download).
2. Mở thư mục `game/` bằng Godot (Import project).
3. Nhấn **F5** (main scene: `scenes/main.tscn`).
4. Phím điều khiển:
   - **A/D** hoặc **←/→**: di chuyển · **W/Space**: nhảy
   - **J**: đấm nhẹ (`light`) · **K**: đấm mạnh (`heavy`) · **L**: đá (`kick`)
   - **S/↓**: thủ (`block`) · **Q**: né (`dodge`) · **E**: lao tới (`dash_fwd`)
   - **1 / 2 / 3 / 4 / 0**: đổi đối thủ (`Rusher` / `Turtle` / `Poker` / `Mirror` / `Random`) · **R/Enter**: chơi lại.

## Chạy headless & Smoke Test

```powershell
# Từ root repo (sau khi cài Godot):
$env:GODOT_EXE = "C:\path\to\Godot_v4.x-stable_win64.exe"
.\scripts\run_headless.ps1

# Chạy smoke test toàn pipeline Tuần 3 (sinh dữ liệu -> train -> export JSON -> kiểm tra parity < 1e-4):
powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke_test.ps1

# Chạy N trận headless giữa 2 bot bất kỳ và ghi CSV:
.\scripts\run_matches.ps1 -P1 rusher -P2 turtle -Matches 500 -ResultsCsv data/raw/matches.csv -LogCsv data/raw/rusher.csv
```

Hoặc trực tiếp:

```text
godot --headless --path game --scene res://scenes/headless_test.tscn
godot --headless --path game --scene res://scenes/headless_parity_test.tscn
```

## Cấu trúc thư mục

```text
mirror-duelist-ai/
├── SPEC.md
├── game/                 # Godot 4 project (character, controllers, mlp, data_logger, match_runner)
├── ml/                   # Python/PyTorch pipeline (dataset, model, train, export_json, smoke_test)
├── scripts/              # PowerShell runners (run_headless, run_matches, run_smoke_test)
├── data/raw, data/models # CSV logs & JSON/PT models
├── results/
└── report/
```
