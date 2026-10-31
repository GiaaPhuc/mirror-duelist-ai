# ML Pipeline (Tuần 3–4+)

Huấn luyện Behavior Cloning (MLP `22 -> 64 -> 64 -> 10`, ReLU) và xuất trọng số JSON cho Godot (`data/models/mirror_*.json` + `data/models/test_vectors_*.json`).

## Cài đặt môi trường

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r ml/requirements.txt
```

*(Lưu ý: `ml/train.py` và `ml/export_json.py` ưu tiên dùng PyTorch khi có `torch`, đồng thời có fallback NumPy float32 tương đương toán học để chạy toàn bộ pipeline ngay cả khi chưa cài `torch`).*

## Các lệnh chính

```powershell
# 1. Smoke test toàn pipeline Tuần 3 (sinh >= 1.000 dòng -> train -> export JSON -> kiểm tra parity < 1e-4)
powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke_test.ps1

# 2. Chạy toàn bộ pipeline Tuần 4 (>= 10.000 mẫu mỗi bot + 15 phiên human_self -> train 3 Mirror bot + Mirror human_self -> báo cáo results/)
powershell -ExecutionPolicy Bypass -File .\scripts\run_week4_baseline.ps1

# 3. Huấn luyện trực tiếp từ file CSV bất kỳ
python ml/train.py --data data/raw/rusher.csv --out-model data/models/mirror_rusher.json --out-ckpt data/models/best_rusher.pt --out-vectors data/models/test_vectors_rusher.json

# 4. Xuất JSON & 20 test vectors từ checkpoint
python ml/export_json.py --checkpoint data/models/best.pt --output data/models/mirror.json --test-vectors data/models/test_vectors.json

# 5. Chạy bộ test tự động Tuần 3 & Tuần 4
python -m pytest ml/test_week3.py ml/test_week4.py -v
```
