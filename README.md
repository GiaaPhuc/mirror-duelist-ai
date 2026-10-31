# Mirror Duelist

Game đối kháng 2D: AI học phong cách chiến đấu của người chơi (Behavior Cloning).

- **Đặc tả:** [SPEC.md](SPEC.md)
- **Kế hoạch 10 tuần:** [Mirror-Duelist-Implementation-Plan.md](Mirror-Duelist-Implementation-Plan.md)
- **Báo cáo baseline Tuần 4:** [results/week4_baseline_report.md](results/week4_baseline_report.md)

## Chạy game (Godot Editor)

1. Cài [Godot 4.3+](https://godotengine.org/download).
2. Mở thư mục `game/` bằng Godot (Import project).
3. Nhấn **F5** (main scene: `scenes/main.tscn`). Mọi trận người chơi đấu sẽ tự động được ghi log (10 Hz, khi actionable) vào `data/raw/human_self.csv`.
4. Phím điều khiển:
   - **A/D** hoặc **←/→**: di chuyển · **W/Space**: nhảy
   - **J**: đấm nhẹ (`light`) · **K**: đấm mạnh (`heavy`) · **L**: đá (`kick`)
   - **S/↓**: thủ (`block`) · **Q**: né (`dodge`) · **E**: lao tới (`dash_fwd`)
   - **1 / 2 / 3 / 0**: đổi đối thủ Bot (`Rusher` / `Turtle` / `Poker` / `Random`)
   - **4 / 5 / 6 / 7 / 8**: đấu với `Mirror` (`Mặc định` / `Mirror-Rusher` / `Mirror-Turtle` / `Mirror-Poker` / `Mirror-Self`)
   - **9**: chế độ xem trực quan **Mirror-X đấu Bot-X** (luân phiên `Rusher` / `Turtle` / `Poker`)
   - **R/Enter**: chơi lại phiên mới.

## Chạy headless, Smoke Test & Baseline Tuần 4

```powershell
# Từ root repo (sau khi cài Godot):
$env:GODOT_EXE = "C:\path\to\Godot_v4.x-stable_win64.exe"
.\scripts\run_headless.ps1

# Chạy smoke test toàn pipeline Tuần 3 (sinh dữ liệu -> train -> export JSON -> kiểm tra parity < 1e-4):
powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke_test.ps1

# Chạy toàn bộ pipeline Tuần 4 (sinh >= 10.000 mẫu/bot + 15 phiên human_self -> train 4 model Mirror -> đánh giá & xuất báo cáo results/):
powershell -ExecutionPolicy Bypass -File .\scripts\run_week4_baseline.ps1

# Chạy N trận headless giữa 2 bot bất kỳ và ghi CSV:
.\scripts\run_matches.ps1 -P1 rusher -P2 rotate -Matches 500 -ResultsCsv data/raw/matches.csv -LogCsv data/raw/rusher.csv
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
├── ml/                   # Python/PyTorch pipeline (dataset, model, train, export_json, smoke_test, week4_baseline)
├── scripts/              # PowerShell runners (run_headless, run_matches, run_smoke_test, run_week4_baseline)
├── data/raw, data/models # CSV logs (rusher, turtle, poker, human_self) & JSON/PT models
├── results/              # Bảng số liệu CSV/JSON, biểu đồ phân phối action & báo cáo baseline Tuần 4
└── report/
```
