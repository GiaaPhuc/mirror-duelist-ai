# ML Pipeline (Tuần 3+)

Huấn luyện Behavior Cloning (MLP `22 -> 64 -> 64 -> 10`, ReLU) và xuất trọng số JSON cho Godot (`data/models/mirror.json` + `data/models/test_vectors.json`).

## Cài đặt môi trường

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r ml/requirements.txt
```

*(Lưu ý: `ml/train.py` và `ml/export_json.py` ưu tiên dùng PyTorch khi có `torch`, đồng thời có fallback NumPy float32 tương đương toán học để chạy smoke test ngay cả khi chưa cài `torch`).*

## Các lệnh chính

```powershell
# 1. Smoke test toàn pipeline (sinh >= 1.000 dòng -> train -> export JSON -> kiểm tra parity < 1e-4)
powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke_test.ps1

# 2. Huấn luyện trực tiếp từ file CSV
python ml/train.py --data data/raw/rusher.csv --out-model data/models/mirror.json

# 3. Xuất JSON & 20 test vectors từ checkpoint
python ml/export_json.py --checkpoint data/models/best.pt --output data/models/mirror.json --test-vectors data/models/test_vectors.json

# 4. Chạy bộ test tự động Tuần 3 (3 bot, 500 trận, parity < 1e-4)
python -m pytest ml/test_week3.py -v
```
