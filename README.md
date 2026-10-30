# Mirror Duelist

Game đối kháng 2D: AI học phong cách chiến đấu của người chơi (Behavior Cloning).

- **Đặc tả:** [SPEC.md](SPEC.md)
- **Kế hoạch 10 tuần:** [Mirror-Duelist-Implementation-Plan.md](Mirror-Duelist-Implementation-Plan.md)

## Trạng thái hiện tại (Tuần 1–3)

- **Tuần 1:** Khung project Godot 4 (`game/`), arena phẳng, `SPEC.md` đóng băng.
- **Tuần 2:** Luật chiến đấu 10 hành động (`character.gd`, `fight_match.gd`), `StateEncoder` 22 chiều (mirror hoá), interface `Controller`, `match_runner.gd`.
- **Tuần 3:**
  - 3 bot rule-based có phong cách riêng + nhiễu `epsilon = 0.12`: `BotRusher`, `BotTurtle`, `BotPoker`.
  - Bộ ghi dữ liệu quyết định 10 Hz khi actionable: `game/scripts/data_logger.gd`.
  - Nâng cấp `match_runner.gd` chạy N trận headless giữa 2 controller bất kỳ (`random`, `rusher`, `turtle`, `poker`, `mirror`, `rotate`), xuất kết quả trận và dữ liệu state-action ra CSV.
  - Inference GDScript (`game/scripts/mlp.gd`, `mirror_controller.gd`) và kiểm tra khớp số với PyTorch (`game/scripts/parity_test.gd`, sai số `< 1e-4`).
  - Pipeline ML (`ml/dataset.py`, `ml/model.py`, `ml/train.py`, `ml/export_json.py`, `ml/smoke_test.py`).

## Chạy game (Godot Editor)

1. Cài [Godot 4.3+](https://godotengine.org/download).
2. Mở thư mục `game/` bằng Godot (Import project) và nhấn **F5** (`scenes/main.tscn`).
3. Phím điều khiển:
   - **A/D** hoặc **←/→**: di chuyển · **W/Space**: nhảy
   - **J**: đấm nhẹ (`light`) · **K**: đấm mạnh (`heavy`) · **L**: đá (`kick`)
   - **S/↓**: thủ (`block`) · **Q**: né (`dodge`) · **E**: lao tới (`dash_fwd`)
   - **1 / 2 / 3 / 4 / 0**: đổi đối thủ (`Rusher` / `Turtle` / `Poker` / `Mirror` / `Random`) · **R/Enter**: chơi lại.

## Chạy headless & Smoke Test toàn pipeline (Tuần 3)

```powershell
# Chạy smoke test toàn pipeline (tự động dùng Godot headless nếu có $env:GODOT_EXE, hoặc Python simulator):
powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke_test.ps1

# Chạy N trận headless giữa 2 bot bất kỳ và ghi CSV (khi đã cài Godot):
$env:GODOT_EXE = "C:\path\to\Godot_v4.x-stable_win64.exe"
.\scripts\run_matches.ps1 -P1 rusher -P2 turtle -Matches 500 -ResultsCsv data/raw/matches.csv -LogCsv data/raw/rusher.csv

# Kiểm tra độ khớp GDScript vs PyTorch trên Godot headless:
& $env:GODOT_EXE --headless --path game --scene res://scenes/headless_parity_test.tscn
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
