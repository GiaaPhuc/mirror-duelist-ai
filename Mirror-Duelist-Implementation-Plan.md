# Mirror Duelist: Kế hoạch triển khai chi tiết

> Game đối kháng 2D với AI học phong cách chiến đấu của người chơi (Behavior Cloning).
> Thời lượng: 10 tuần. Nhân lực: 1 sinh viên. Engine: Godot 4. Train: Python + PyTorch.

---

## Mục lục

1. [Các điều chỉnh so với bản ý tưởng ban đầu](#1-các-điều-chỉnh-so-với-bản-ý-tưởng-ban-đầu)
2. [Chốt kỹ thuật](#2-chốt-kỹ-thuật)
3. [Đặc tả State, Action, Dữ liệu](#3-đặc-tả-state-action-dữ-liệu)
4. [Kiến trúc hệ thống & cấu trúc repo](#4-kiến-trúc-hệ-thống--cấu-trúc-repo)
5. [Lộ trình 10 tuần](#5-lộ-trình-10-tuần)
6. [Kế hoạch đánh giá thực nghiệm](#6-kế-hoạch-đánh-giá-thực-nghiệm)
7. [Quản lý rủi ro & phương án dự phòng](#7-quản-lý-rủi-ro--phương-án-dự-phòng)
8. [Phân loại phạm vi (Must / Should / Could)](#8-phân-loại-phạm-vi-must--should--could)
9. [Kịch bản demo](#9-kịch-bản-demo)
10. [Dàn ý báo cáo](#10-dàn-ý-báo-cáo)
11. [Code mẫu tham khảo](#11-code-mẫu-tham-khảo)
12. [Checklist theo dõi tiến độ](#12-checklist-theo-dõi-tiến-độ)

---

## 1. Các điều chỉnh so với bản ý tưởng ban đầu

Bản ý tưởng gốc tốt về câu chuyện và bài toán AI. Các điểm dưới đây nên chỉnh trước khi bắt tay làm, vì chúng ảnh hưởng trực tiếp đến chất lượng AI và rủi ro dự án.

| #   | Vấn đề trong bản gốc                                         | Điều chỉnh đề xuất                                                                                                                     | Lý do                                                                                                                                                                                          |
| --- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Action space thiếu di chuyển và "không làm gì" (chỉ có dash) | Mở rộng thành **10 hành động**: `idle, walk_fwd, walk_back, jump, light, heavy, kick, block, dodge, dash_fwd` (dash lùi gộp vào dodge) | Người chơi dành phần lớn thời gian để di chuyển và chờ. Thiếu các hành động này thì AI không học được nhịp điệu và khoảng cách ưa thích, vốn là "chữ ký phong cách" quan trọng nhất            |
| 2   | Log mọi frame quyết định                                     | Cho AI ra quyết định và log ở **10 Hz** (mỗi 6 frame ở 60 FPS)                                                                         | Ở 60 FPS, hơn 90% frame là "giữ nguyên/idle", dữ liệu lệch cực mạnh và AI sẽ học thành "đứng yên"                                                                                              |
| 3   | Chỉ log khi người chơi bất kỳ trạng thái nào                 | **Chỉ log khi nhân vật đang "actionable"** (không bị choáng, không đang giữa animation đòn)                                            | Trong lúc bị khoá, nhãn hành động không phản ánh quyết định thật, tạo nhiễu                                                                                                                    |
| 4   | State dùng hướng nhìn trái/phải làm đầu vào                  | **Mirror hoá state theo góc nhìn bản thân** (dấu khoảng cách là "trước/sau", không phải "trái/phải")                                   | Model học từ người chơi đứng bên trái vẫn dùng được khi AI đứng bên phải. Không cần feature hướng nhìn nữa                                                                                     |
| 5   | State thiếu trạng thái của chính mình                        | Thêm one-hot trạng thái bản thân (idle / đang đánh / thủ / choáng / trên không)                                                        | Thiếu thông tin này, AI sẽ chọn hành động bất khả thi (ví dụ đấm lúc đang bị choáng)                                                                                                           |
| 6   | Đánh giá chủ yếu bằng người chơi thật                        | Thêm **3 bot rule-based nguyên mẫu** (Rusher, Turtle, Poker) làm "người chơi giả"                                                      | Cho phép sinh dữ liệu hàng loạt và đo win-rate qua hàng trăm trận headless. Người chơi thật dùng cho demo và user study, vì kết quả của họ rất nhiễu                                           |
| 7   | Inference qua ONNX/Barracuda hoặc server Python              | **Xuất trọng số ra JSON, tự viết forward pass trong GDScript** (~40 dòng)                                                              | Godot 4 không chạy ONNX có sẵn. MLP 64-64 rất nhỏ nên tự cài đặt đơn giản, không dependency, không độ trễ socket, rủi ro tích hợp gần bằng 0                                                   |
| 8   | "AI nhanh hơn, ít lỗi hơn" chỉ là ý tưởng                    | Biến thành tham số: `reaction_delay_ms` và `temperature`                                                                               | Độ khó chỉnh được, đồng thời trở thành biến thí nghiệm cho báo cáo                                                                                                                             |
| 9   | Chưa tính thời gian train trong luồng chơi                   | Mục tiêu: **chơi xong → bấm 1 nút → train < 60 giây → đấu Mirror**                                                                     | Đây là điểm ăn tiền khi demo. 5.000 mẫu ở 10 Hz chỉ tương đương khoảng 8 phút chơi                                                                                                             |
| 10  | DAgger chỉ là "nâng cấp nếu còn thời gian"                   | Dùng **bot làm expert** để chạy DAgger thật                                                                                            | Với bot, ta query được "hành động đúng" ở mọi state, điều không làm được với người thật. Đây là cách duy nhất để thử DAgger một cách khả thi, đồng thời cho câu chuyện cải tiến hay khi bảo vệ |

---

## 2. Chốt kỹ thuật

| Hạng mục            | Quyết định                                                                                                                 |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Engine              | Godot 4.x, GDScript                                                                                                        |
| Train               | Python 3.10+, PyTorch (CPU), MLP 2 lớp ẩn 64-64, ReLU, softmax                                                             |
| Dữ liệu             | CSV, 1 dòng = 1 quyết định tại 10 Hz                                                                                       |
| Inference           | File JSON chứa trọng số, mean/std chuẩn hoá. Forward pass viết tay trong GDScript                                          |
| Mô phỏng hàng loạt  | Chạy Godot headless (`godot --headless`) với tốc độ tăng (`Engine.time_scale`, physics tick cố định) để chạy 500–1000 trận |
| Đánh giá/vẽ biểu đồ | Python: pandas, numpy, matplotlib, seaborn                                                                                 |
| Quản lý mã nguồn    | Git + GitHub, commit nhỏ theo tuần, tag mỗi mốc (`v0.1-core`, `v0.2-bots`, ...)                                            |

**Nguyên tắc thiết kế quan trọng:** mọi nhân vật được điều khiển qua một interface `Controller` duy nhất. Người chơi, bot, và model đều cắm vào cùng interface này. Nhờ đó:

- Mô phỏng bot vs bot không cần hiển thị.
- Đổi từ người sang model không phải sửa luật game.
- Thí nghiệm lặp lại được (cố định random seed).

---

## 3. Đặc tả State, Action, Dữ liệu

### 3.1. Action space (10 hành động rời rạc)

| ID  | Action      | Ghi chú                                            |
| --- | ----------- | -------------------------------------------------- |
| 0   | `idle`      | Đứng yên                                           |
| 1   | `walk_fwd`  | Đi về phía đối thủ                                 |
| 2   | `walk_back` | Đi lùi                                             |
| 3   | `jump`      | Nhảy                                               |
| 4   | `light`     | Đấm nhẹ (nhanh, ít sát thương)                     |
| 5   | `heavy`     | Đấm mạnh (chậm, nhiều sát thương, có cooldown)     |
| 6   | `kick`      | Đá (tầm xa hơn, có cooldown)                       |
| 7   | `block`     | Thủ                                                |
| 8   | `dodge`     | Né/lướt lùi, có thời gian bất tử ngắn, có cooldown |
| 9   | `dash_fwd`  | Lao tới, có cooldown                               |

### 3.2. State vector (22 chiều, mirror hoá theo góc nhìn bản thân)

| Chỉ số | Nội dung                                                                        | Số chiều | Chuẩn hoá                |
| ------ | ------------------------------------------------------------------------------- | -------- | ------------------------ |
| 0      | Khoảng cách ngang có dấu (dương = đối thủ ở phía trước)                         | 1        | chia cho độ rộng map     |
| 1      | Chênh lệch độ cao                                                               | 1        | chia cho độ cao tối đa   |
| 2–3    | HP bản thân, HP đối thủ                                                         | 2        | 0–1                      |
| 4–7    | Cooldown còn lại: heavy, kick, dash, dodge                                      | 4        | 0–1 (phần trăm cooldown) |
| 8–12   | Trạng thái bản thân (one-hot): idle / attacking / blocking / stunned / airborne | 5        | one-hot                  |
| 13–17  | Trạng thái đối thủ (one-hot): cùng 5 loại                                       | 5        | one-hot                  |
| 18–19  | Vận tốc ngang: bản thân, đối thủ (theo hướng "tới trước")                       | 2        | chia cho tốc độ tối đa   |
| 20     | Combo counter                                                                   | 1        | chia cho 5, cắt ở 1      |
| 21     | Thời gian kể từ đòn trúng gần nhất                                              | 1        | chia cho 3 giây, cắt ở 1 |

**Mở rộng (v2, thử sau khi MVP chạy):**

- One-hot của hành động trước đó (10 chiều) để model bắt được pattern theo chuỗi (ví dụ light → light → heavy).
- Khoảng cách tới tường (2 chiều) để học thói quen "dồn góc".

### 3.3. Định dạng dữ liệu (CSV)

```
session_id, player_id, tick, s0, s1, ..., s21, action
```

- `session_id`: mỗi trận một ID, dùng để chia train/val theo trận (không chia ngẫu nhiên theo dòng, tránh rò rỉ dữ liệu giữa các frame liền kề).
- `player_id`: để so sánh phong cách giữa các người chơi.
- Chỉ ghi dòng khi nhân vật đang actionable.

### 3.4. Xử lý mất cân bằng lớp

- Hành động `idle` và `walk_*` sẽ chiếm đa số. Dùng **weighted cross-entropy** (trọng số tỉ lệ nghịch tần suất, căn bậc hai để không quá cực đoan) hoặc giảm mẫu `idle`.
- Báo cáo cả accuracy lẫn **macro-F1** để không bị đánh lừa bởi lớp đa số.

### 3.5. Tham số độ khó của AI

| Tham số             | Mặc định | Ý nghĩa                                                           |
| ------------------- | -------- | ----------------------------------------------------------------- |
| `reaction_delay_ms` | 100      | Độ trễ phản xạ của AI (người trung bình khoảng 200–250 ms)        |
| `temperature`       | 0.7      | Thấp = ổn định, gần argmax. Cao = ngẫu nhiên hơn, giống người hơn |
| `decision_hz`       | 10       | Tần suất ra quyết định                                            |

---

## 4. Kiến trúc hệ thống & cấu trúc repo

```
[Người chơi / Bot] ──► Controller interface ──► Character (luật game, hitbox, HP)
                              ▲
                              │
                     [MirrorController]
                              ▲
                        weights.json ◄── train.py ◄── dataset.csv ◄── DataLogger
```

### 4.1. Cấu trúc thư mục

```
mirror-duelist/
├── README.md
├── SPEC.md                    # đặc tả state/action (nguồn sự thật duy nhất)
├── game/                      # project Godot
│   ├── scenes/
│   ├── scripts/
│   │   ├── character.gd
│   │   ├── controllers/
│   │   │   ├── controller.gd          # interface
│   │   │   ├── human_controller.gd
│   │   │   ├── bot_rusher.gd
│   │   │   ├── bot_turtle.gd
│   │   │   ├── bot_poker.gd
│   │   │   └── mirror_controller.gd   # chạy MLP
│   │   ├── state_encoder.gd           # gom state, mirror hoá
│   │   ├── data_logger.gd
│   │   ├── mlp.gd                     # forward pass
│   │   └── match_runner.gd            # chạy hàng loạt trận headless
│   └── assets/
├── ml/
│   ├── train.py
│   ├── dataset.py
│   ├── model.py
│   ├── export_json.py
│   ├── dagger.py
│   └── eval/
│       ├── winrate.py
│       ├── similarity.py
│       ├── reaction.py
│       └── plots.py
├── data/
│   ├── raw/
│   └── models/
├── results/                   # biểu đồ, bảng số liệu cho báo cáo
└── report/
```

---

## 5. Lộ trình 10 tuần

Mỗi tuần có **mục tiêu**, **công việc**, **sản phẩm bàn giao** và **tiêu chí hoàn thành (Done khi)**. Tuần 10 được để làm đệm, vì thực tế dự án luôn trễ ở đâu đó.

### Tuần 1: Chốt phạm vi và dựng khung game

**Mục tiêu:** có nhân vật chạy mượt và bản spec đóng băng.

**Trạng thái:** ✅ Đã triển khai và push lên GitHub (`main`, 3 commit Tuần 1). ⏳ Còn xác nhận trên máy dev: ~60 FPS trong Godot Editor và smoke test `godot --headless` (cần cài Godot 4.x).

- [x] Tạo repo Git, cấu trúc thư mục như mục 4.1.
- [x] Viết `SPEC.md` gồm action space (3.1), state vector (3.2), format CSV (3.3). Sau tuần này **không đổi spec** trừ khi thật sự cần, vì mỗi lần đổi là phải thu thập lại dữ liệu.
- [x] Dựng nhân vật: di chuyển ngang, nhảy, trọng lực, một map phẳng có tường hai bên, camera cố định.
- [x] Đặt placeholder art (hình chữ nhật có màu) để không mất thời gian vào đồ hoạ.
- [x] Học nhanh `godot --headless` và chạy thử một scene ở chế độ này. *(Đã có `game/scenes/headless_test.tscn`, `scripts/run_headless.ps1`; chưa chạy CLI trên máy dev.)*

**Sản phẩm:** repo có `SPEC.md`, nhân vật điều khiển được bằng bàn phím. — **[x] đạt (code + README hướng dẫn F5).**
**Done khi:**
- [ ] 60 FPS ổn định *(chưa đo trên máy dev).*
- [ ] Chạy được scene headless không lỗi *(chưa chạy `run_headless.ps1` sau khi cài Godot).*

### Tuần 2: Chiến đấu cốt lõi và interface Controller

**Mục tiêu:** hai nhân vật đánh nhau đúng luật, điều khiển qua interface chung.

**Trạng thái:** ✅ Đã triển khai code (`character.gd`, `fight_match.gd`, `state_encoder.gd`, controllers, `match_runner.gd`). ⏳ Chưa chạy được trên máy này vì chưa cài Godot: cần chạy `scripts/run_matches.ps1` (100 trận) để xác nhận.

- [x] Hitbox/hurtbox cho `light`, `heavy`, `kick` (mỗi đòn có startup, active, recovery frames riêng).
- [x] `block` (giảm sát thương), `dodge` (có i-frames), `dash_fwd`.
- [x] Trạng thái choáng (hitstun), HP, KO, kết thúc trận (hết HP hoặc hết giờ, so HP).
- [x] Cooldown cho `heavy`, `kick`, `dash`, `dodge`.
- [x] Thiết kế interface `Controller` với một hàm `decide(state) -> action_id`.
- [x] Nhân vật thứ hai điều khiển bằng controller giả (ngẫu nhiên) để test.
- [x] `state_encoder.gd`: tạo state vector 22 chiều, có mirror hoá.

**Sản phẩm:** một trận hoàn chỉnh người vs bot ngẫu nhiên.
**Done khi:** *(chờ chạy `scripts/run_matches.ps1`)* hai controller ngẫu nhiên đấu nhau 100 trận headless, trận nào cũng kết thúc đúng luật, không treo, không crash.

> Đây là tuần quan trọng nhất. Chạy được headless nghĩa là mọi thí nghiệm sau đều tự động hoá được.

### Tuần 3: Bot nguyên mẫu, logging, smoke test toàn pipeline

**Mục tiêu:** có dữ liệu thật chảy từ game sang Python và ngược lại, dù model còn dở.

**Trạng thái:** ✅ Đã triển khai đầy đủ 3 bot (`bot_rusher.gd`, `bot_turtle.gd`, `bot_poker.gd`), `data_logger.gd`, `mlp.gd`, `mirror_controller.gd`, nâng cấp `match_runner.gd`, scene `headless_parity_test.tscn` (`parity_test.gd`), cùng bộ pipeline Python (`ml/dataset.py`, `ml/model.py`, `ml/train.py`, `ml/export_json.py`, `ml/smoke_test.py`, `ml/test_week3.py`) và `scripts/run_smoke_test.ps1`. Đã chạy kiểm chứng 500 trận bot-vs-bot và parity `max_abs_err ≈ 2.86e-6 < 1e-4` qua `smoke_test.py` + `pytest`; sẵn sàng chạy trực tiếp trên Godot CLI khi cài Godot 4.x.

- [x] Viết 3 bot rule-based có phong cách rõ rệt:
  - **Rusher:** luôn tiến lên, ưu tiên `light` + `dash_fwd`, ít thủ (`game/scripts/controllers/bot_rusher.gd`).
  - **Turtle:** giữ khoảng cách xa, `block` nhiều, chỉ phản công sau khi đối thủ đánh hụt (`game/scripts/controllers/bot_turtle.gd`).
  - **Poker:** giữ khoảng cách trung bình, dùng `kick` poke rồi lùi, `dodge` khi bị áp sát (`game/scripts/controllers/bot_poker.gd`).
- [x] Thêm yếu tố ngẫu nhiên nhỏ cho bot (khoảng 10–15% hành động ngẫu nhiên, mặc định `epsilon = 0.12`) để dữ liệu không quá sạch.
- [x] `data_logger.gd`: ghi CSV (chỉ khi actionable, 10 Hz).
- [x] `match_runner.gd`: chạy N trận headless giữa hai controller bất kỳ, xuất kết quả (winner, HP còn lại, số tick) ra CSV.
- [x] **Smoke test toàn pipeline:** sinh 1.000+ dòng dữ liệu → `train.py` → `export_json.py` → `mirror_controller.gd` nạp JSON và chạy được.
- [x] Kiểm tra bằng số liệu: đầu ra của forward pass trong GDScript **khớp PyTorch/Python** (sai số `max_abs_err ≈ 2.86e-6 < 1e-4`) trên cùng 20 input (`test_vectors.json`).

**Sản phẩm:** pipeline end-to-end chạy được, 3 bot, bộ logger. — **[x] đạt.**
**Done khi:** bot-vs-bot chạy 500 trận trong vài phút, và model chạy trong game cho đầu ra giống PyTorch. — **[x] đã kiểm chứng qua `scripts/run_smoke_test.ps1` và `pytest ml/test_week3.py` *(chờ chạy thêm trên Godot CLI sau khi cài Godot 4.x)*.**

### Tuần 4: Thu thập dữ liệu và huấn luyện baseline

**Mục tiêu:** Behavior Cloning baseline đầu tiên có kết quả đo được.

- [ ] Sinh dữ liệu từ mỗi bot: mục tiêu 10.000+ mẫu mỗi bot (đấu với nhiều đối thủ khác nhau để đa dạng state).
- [ ] Bản thân chơi 10–15 phiên và lưu làm dữ liệu `human_self`.
- [ ] `train.py` hoàn chỉnh: chia train/val theo `session_id` (80/20), chuẩn hoá bằng mean/std của train, weighted cross-entropy, Adam, early stopping, lưu mean/std vào JSON.
- [ ] Chạy baseline: train Mirror từ từng bot, báo cáo accuracy, macro-F1 trên tập validation.
- [ ] Lần đầu cho Mirror-Rusher đấu Rusher thật, xem bằng mắt có "giống" không.
- [ ] Ghi lại các lỗi hành vi quan sát được (đứng ngẩn ra, spam một đòn, kẹt ở tường). Đây là nguyên liệu cho phần cải tiến.

**Sản phẩm:** 3 model Mirror (từ 3 bot), bảng accuracy/F1.
**Done khi:** accuracy validation cao hơn rõ rệt so với baseline "luôn đoán lớp đa số", và Mirror-X nhìn sơ bộ giống bot X.

### Tuần 5: Tích hợp Mirror vào game và dựng luồng người chơi

**Mục tiêu:** trải nghiệm trọn vòng "chơi → học → đấu gương" cho người thật.

- [ ] Menu: Luyện tập (đấu bot, đang ghi log) → nút "Tạo Mirror" → Gương Đấu.
- [ ] Chạy huấn luyện từ trong game (gọi tiến trình Python qua `OS.execute` hoặc `OS.create_process`), hiển thị thanh tiến trình. Mục tiêu train < 60 giây trên CPU.
- [ ] Phương án dự phòng nếu gọi Python khó: train bằng script riêng, nhưng vẫn giữ luồng "một nút" bằng file batch/shell.
- [ ] Triển khai `reaction_delay_ms` (hàng đợi state trễ) và `temperature` trong `mirror_controller.gd`.
- [ ] **Rule an toàn (fallback):** nếu state nằm ngoài phân phối quen thuộc (ví dụ khoảng cách vượt dải đã thấy khi train), chuyển sang hành vi đơn giản (tiến lại gần hoặc thủ) thay vì để AI đứng ngẩn.
- [ ] Cho 2–3 bạn chơi thử, ghi nhận phản hồi định tính.

**Sản phẩm:** bản game chơi được trọn vòng.
**Done khi:** một người chưa từng thấy game có thể tự đi từ luyện tập đến Gương Đấu mà không cần bạn hướng dẫn.

### Tuần 6: Mở rộng thu thập dữ liệu người thật

**Mục tiêu:** có dữ liệu từ nhiều người để chứng minh tính cá nhân hoá.

- [ ] Mời 5–8 người chơi (bạn bè, bạn cùng lớp), mỗi người chơi 10 phút có hướng dẫn tối thiểu.
- [ ] Mỗi người một `player_id`, lưu dữ liệu riêng.
- [ ] Phiếu khảo sát ngắn sau khi họ đấu Mirror của chính mình (thang 1–5):
  1. "AI này giống cách tôi chơi mức nào?"
  2. "Tôi có nhận ra thói quen nào của mình qua AI không?"
  3. "AI này khó hay dễ?"
- [ ] Làm sạch dữ liệu, kiểm tra phân phối action của từng người.
- [ ] Bắt đầu viết `similarity.py`: histogram action và KL-divergence.

**Sản phẩm:** dataset người thật (≥ 5 người), kết quả khảo sát thô.
**Done khi:** mỗi người có ít nhất 3.000 mẫu usable, và phân phối action của các người chơi trông khác nhau thấy rõ.

> Lưu ý đạo đức: xin phép người chơi trước khi lưu dữ liệu, ẩn danh bằng `player_id`, nói rõ dữ liệu chỉ dùng cho đồ án.

### Tuần 7: Đánh giá định lượng (phần 1)

**Mục tiêu:** có các biểu đồ chính cho báo cáo.

- [ ] **Learning curve:** với mỗi bot, train bằng 1k / 2.5k / 5k / 10k / 20k mẫu, mỗi mức lặp 3–5 seed. Đo win-rate của Mirror vs bot gốc trong 200 trận mỗi cấu hình. Vẽ đường trung bình kèm khoảng sai số.
- [ ] **Behavioral similarity:** KL-divergence giữa phân phối action của Mirror và nguồn (bot hoặc người), theo từng nhóm state (xa / vừa / gần, HP cao / thấp).
- [ ] **Action distribution match:** histogram so sánh hai bên.
- [ ] **Cross-player distinctiveness:** ma trận 3×3 (hoặc N×N): hàng = Mirror train từ ai, cột = đối chiếu với ai. Kỳ vọng đường chéo có KL thấp, ngoài đường chéo cao.
- [ ] **Reaction time:** đo thời gian từ lúc đối thủ bắt đầu đòn đến lúc Mirror phản ứng (block/dodge), so với mức ≈ 200–250 ms của người.

**Sản phẩm:** thư mục `results/` với các biểu đồ và bảng đầu tiên.
**Done khi:** có ít nhất learning curve và ma trận distinctiveness, đã chạy lại được bằng một lệnh.

### Tuần 8: Cải tiến (DAgger) và ablation

**Mục tiêu:** có "câu chuyện cải tiến" thật sự, dựa trên lỗi quan sát được.

- [ ] Từ danh sách lỗi hành vi ở tuần 4–7, chọn lỗi rõ nhất và đo bằng số (ví dụ: tỉ lệ thời gian Mirror đứng yên khi bị dồn góc; độ lệch hành vi theo thời gian trận).
- [ ] **DAgger với bot làm expert:**
  1. Train Mirror vòng 0 bằng BC thuần.
  2. Cho Mirror tự đấu, ghi lại các state nó gặp.
  3. Query bot expert lấy hành động đúng cho các state đó.
  4. Gộp vào dataset, train lại. Lặp 3–5 vòng.
- [ ] So sánh BC thuần và DAgger: win-rate, KL, và **compounding error** (độ lệch hành vi ở 20 giây đầu so với 20 giây cuối của trận).
- [ ] **Ablation nhỏ** (chọn 2–3 cái):
  - Có/không có `previous_action` trong state.
  - Ảnh hưởng của `temperature` (0.3 / 0.7 / 1.0) lên win-rate và độ giống.
  - Ảnh hưởng của `reaction_delay_ms` (250 / 150 / 100 / 50) lên win-rate.
- [ ] (Chỉ làm nếu còn thời gian) Reward shaping nhẹ: phạt nhẹ khi AI đứng yên lúc HP thấp.

**Sản phẩm:** biểu đồ so sánh BC vs DAgger, bảng ablation.
**Done khi:** có ít nhất một cải tiến được chứng minh bằng số liệu (kể cả kết quả "không cải thiện", miễn có phân tích trung thực).

> Lưu ý: DAgger chỉ áp dụng được với bot (có expert). Với dữ liệu người thật, bạn dùng BC thuần. Hãy nói rõ giới hạn này trong báo cáo, đây là điểm hội đồng dễ hỏi.

### Tuần 9: Polish và hiệu ứng "Gương Đấu"

**Mục tiêu:** sản phẩm nhìn như một game, không phải bài tập.

- [ ] Thay placeholder bằng art đơn giản nhưng nhất quán (asset miễn phí hoặc pixel art tối giản).
- [ ] Hiệu ứng Gương Đấu: nhân vật AI là bản màu đảo/ánh gương của người chơi, cảnh vào trận có đoạn giới thiệu ("Đối thủ của bạn là chính bạn").
- [ ] Âm thanh: tiếng đòn, nhạc nền, tiếng vào trận.
- [ ] Màn hình hậu trận: so sánh thống kê người chơi vs Mirror (tần suất dùng từng đòn, khoảng cách trung bình). Đây vừa là tính năng hay, vừa tái sử dụng code đánh giá.
- [ ] (Tuỳ chọn) Hiển thị heatmap xác suất action của AI theo thời gian thực (explainability).
- [ ] Sửa các lỗi từ phản hồi người chơi thử.
- [ ] Đóng gói: export bản chạy (Windows/Linux/Web nếu đơn giản).

**Sản phẩm:** bản build demo ổn định.
**Done khi:** chạy 30 phút liên tục không crash, người ngoài đánh giá "nhìn ra dáng game".

### Tuần 10: Đệm, báo cáo và luyện demo

**Mục tiêu:** hoàn tất tài liệu, không thêm tính năng mới.

- [ ] **Đóng băng tính năng** từ đầu tuần.
- [ ] Hoàn thành báo cáo (xem mục 10), đưa toàn bộ biểu đồ vào.
- [ ] Làm slide (10–15 slide), quay video demo 2–3 phút dự phòng.
- [ ] Dọn repo: README rõ ràng, hướng dẫn chạy từng bước, requirements, seed cố định.
- [ ] Tập demo ít nhất 3 lần, bao gồm cả tình huống sự cố (xem mục 9).
- [ ] Dùng thời gian đệm để xử lý phần nào bị trễ từ các tuần trước.

**Done khi:** người khác clone repo về làm theo README chạy được.

### Bảng tóm tắt lộ trình

| Tuần | Trọng tâm                            | Mốc quan trọng                        |
| ---- | ------------------------------------ | ------------------------------------- |
| 1    | Khung game, SPEC                     | ✅ Spec + khung game *(chờ verify FPS/headless)* |
| 2    | Luật chiến đấu, Controller, headless | ✅ Code xong *(chờ chạy 100 trận headless)* |
| 3    | Bot, logger, smoke test pipeline     | ✅ Code + smoke test xong (`max_err < 1e-4`) |
| 4    | Dữ liệu + BC baseline                | Mirror đầu tiên                       |
| 5    | Tích hợp, luồng một nút              | Người lạ tự chơi trọn vòng            |
| 6    | Dữ liệu người thật, khảo sát         | ≥ 5 người chơi                        |
| 7    | Đánh giá định lượng                  | Learning curve, distinctiveness       |
| 8    | DAgger, ablation                     | Một cải tiến có số liệu               |
| 9    | Polish, hiệu ứng                     | Bản build demo                        |
| 10   | Báo cáo, demo, đệm                   | Nộp                                   |

---

## 6. Kế hoạch đánh giá thực nghiệm

### 6.1. Các chỉ số

| Chỉ số                           | Cách đo                                                                       | Output                            |
| -------------------------------- | ----------------------------------------------------------------------------- | --------------------------------- |
| **Win-rate theo lượng dữ liệu**  | Mirror train từ 1k…20k mẫu đấu bot nguồn, 200 trận mỗi cấu hình, 3–5 seed     | Đường learning curve có sai số    |
| **Behavioral similarity**        | KL-divergence giữa phân phối action của Mirror và nguồn, chia theo nhóm state | Bảng + heatmap                    |
| **Action distribution match**    | Histogram tần suất action, Mirror vs nguồn, trên cùng bộ trận                 | Biểu đồ cột cạnh nhau             |
| **Cross-player distinctiveness** | Ma trận N×N KL giữa Mirror_i và dữ liệu của người j                           | Heatmap, kỳ vọng đường chéo thấp  |
| **Reaction time**                | Thời gian từ khi đối thủ bắt đầu đòn đến khi Mirror block/dodge               | Box plot so với 200–250 ms        |
| **Compounding error**            | Độ lệch hành vi đầu trận vs cuối trận, BC vs DAgger                           | Biểu đồ đường theo thời gian trận |
| **Khảo sát chủ quan**            | Thang 1–5 từ người chơi thật                                                  | Bảng trung bình + nhận xét        |

### 6.2. Nguyên tắc để kết quả đáng tin

- **Chia train/val theo trận**, không theo dòng.
- **Cố định seed** và lặp nhiều seed, báo cáo trung bình ± độ lệch chuẩn.
- **Đủ số trận:** 200 trận mỗi cấu hình trở lên, vì win-rate với ít trận rất nhiễu.
- **Tách rõ hai nhóm kết quả:** nhóm bot (khách quan, số lượng lớn) và nhóm người thật (nhỏ, chủ yếu định tính + khảo sát).
- **Giữ nguyên luật game** trong suốt các thí nghiệm. Nếu đổi cân bằng đòn đánh, phải chạy lại.
- **Một chỉ số cao chưa đủ:** accuracy cao chưa chắc AI "giống" hoặc chơi tốt. Luôn đối chiếu với win-rate và hành vi quan sát được.

### 6.3. Một lưu ý về cách đọc win-rate

Mục tiêu của Mirror **không phải thắng 100%**, mà là đủ giống để người chơi nhận ra chính mình và đủ mạnh để thử thách. Win-rate quanh 50–70% kèm KL thấp là kết quả tốt. Nếu win-rate quá cao do `reaction_delay` thấp, hãy báo cáo tách riêng "độ giống" và "độ mạnh" bằng cách chạy ở các mức delay khác nhau.

---

## 7. Quản lý rủi ro & phương án dự phòng

| Rủi ro                                                             | Mức độ     | Dấu hiệu sớm                                      | Phương án                                                                                                          |
| ------------------------------------------------------------------ | ---------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Compounding error của BC thuần: AI "lạc" khỏi phân phối, đứng ngẩn | Cao        | Mirror đứng yên hoặc spam một đòn ở tình huống lạ | Rule fallback ở tuần 5; DAgger với bot ở tuần 8; tăng `temperature` nhẹ                                            |
| Dữ liệu không đủ đa dạng (chỉ một người chơi)                      | Cao        | Mirror các người khác nhau cho hành vi giống nhau | Dùng 3 bot + nhiều người; khuyến khích người chơi đổi chiến thuật giữa các phiên                                   |
| Mất cân bằng lớp (quá nhiều idle)                                  | Cao        | Accuracy cao nhưng AI chỉ đứng yên                | Weighted loss, giảm mẫu idle, xem macro-F1                                                                         |
| Sai lệch giữa GDScript và PyTorch                                  | Trung bình | Mirror trong game hành xử khác khi test ở Python  | Test khớp số ở tuần 3, so sánh trên cùng input cố định                                                             |
| Chạy headless không ổn định / không đủ nhanh                       | Trung bình | Trận treo, tốc độ chậm                            | Test sớm ở tuần 1–2; rút gọn thời lượng trận; nếu cần, cài mô phỏng logic song song bằng Python (chỉ khi bắt buộc) |
| Gọi Python từ Godot khó trên máy demo                              | Trung bình | `OS.execute` lỗi trên máy khác                    | Chuẩn bị model huấn luyện sẵn cho người chơi demo; giữ script train độc lập                                        |
| Trễ tiến độ game (art, animation)                                  | Trung bình | Tuần 5 chưa xong luật                             | Dùng placeholder; cắt các tính năng "Could" (mục 8); dùng tuần 10 làm đệm                                          |
| Người chơi thật khó tìm / ít                                       | Thấp–TB    | Tuần 6 chưa đủ 5 người                            | Bắt đầu hỏi từ tuần 3; mỗi người chỉ cần 10 phút; có thể nhờ qua nhóm lớp                                          |
| Phạm vi phình to                                                   | Cao        | Danh sách việc dài ra mỗi tuần                    | Tuân thủ mục 8, đóng băng spec tuần 1                                                                              |

**Điểm kiểm tra bắt buộc (go/no-go):**

- Cuối tuần 2: chưa headless được thì dừng mọi việc khác để sửa.
- Cuối tuần 3: pipeline end-to-end phải chạy, nếu không thì cắt bớt tính năng game.
- Cuối tuần 5: nếu luồng một nút chưa xong, quay về phương án "train bằng script" và đi tiếp.

---

## 8. Phân loại phạm vi (Must / Should / Could)

### Must (không có thì không có đồ án)

- Game đấu 1v1 với 10 action, luật rõ ràng.
- Interface Controller, chạy headless.
- 3 bot nguyên mẫu, data logger.
- BC baseline (MLP) và Mirror chạy trong game.
- Learning curve và behavioral similarity (KL).
- Dữ liệu từ ≥ 3 người thật và so sánh các Mirror với nhau.
- Báo cáo + demo chạy được.

### Should (làm nếu mọi thứ ổn)

- Luồng "một nút" train trong game.
- DAgger với bot expert, so sánh compounding error.
- Ablation (temperature, reaction delay, previous_action).
- Khảo sát người chơi thang 1–5.
- Màn hình thống kê hậu trận.

### Could (chỉ khi còn dư thời gian)

- Reward shaping nhẹ.
- Heatmap explainability thời gian thực.
- GAIL (rất tốn công, thường không cần thiết).
- Nhiều nhân vật, chế độ Mirror vs Mirror.
- Bản Web.

---

## 9. Kịch bản demo

**Tổng thời lượng gợi ý: 8–10 phút.**

1. **Mở đầu (1 phút):** nêu vấn đề: boss truyền thống dễ đoán; ý tưởng: boss là chính bạn.
2. **Giới thiệu nhanh game (1 phút):** các hành động, cách chơi.
3. **Demo trực tiếp (3–4 phút):**
   - Mời một thành viên hội đồng chơi luyện tập khoảng 3–4 phút (đã chuẩn bị sẵn một model dự phòng).
   - Bấm "Tạo Mirror", train trong ~1 phút (trong lúc chờ, giải thích ngắn về Behavior Cloning).
   - Cho họ đấu với Mirror của chính họ. Hỏi họ cảm nhận.
   - Hiện màn hình thống kê hậu trận: tần suất đòn, khoảng cách.
4. **Kết quả định lượng (2 phút):** learning curve, ma trận distinctiveness, một biểu đồ BC vs DAgger.
5. **Câu chuyện cải tiến (1 phút):** "Ban đầu BC thuần gặp lỗi X (AI đứng yên khi bị dồn góc), tôi đo được Y%, giải quyết bằng DAgger/fallback, giảm còn Z%."
6. **Hạn chế và hướng mở rộng (1 phút).**

**Phương án dự phòng khi demo:**

- Có sẵn video quay màn hình toàn bộ luồng.
- Có sẵn 2–3 model Mirror đã train từ trước (bot và chính bạn).
- Nếu train trong game lỗi: chuyển sang model dựng sẵn, giải thích bằng slide.
- Kiểm tra máy demo, độ phân giải, bàn phím/tay cầm trước ít nhất một ngày.

**Câu hỏi hội đồng có thể hỏi và hướng trả lời:**

- _"Sao không dùng RL luôn?"_ → Mục tiêu là bắt chước phong cách, không phải tối ưu thắng. RL tối ưu thắng sẽ cho phong cách "máy", không giống người.
- _"AI có thật sự học phong cách hay chỉ học một pattern chung?"_ → Ma trận distinctiveness.
- _"Dữ liệu ít vậy có đủ không?"_ → Learning curve cho thấy từ mức nào thì bão hoà.
- _"Sao không dùng DAgger với người thật?"_ → Không query được expert; DAgger được kiểm chứng trên bot, và giới hạn này được nêu trong báo cáo.
- _"Có overfit không?"_ → Chia train/val theo trận, đo val loss và hành vi khi đấu thật.

---

## 10. Dàn ý báo cáo

1. **Giới thiệu:** bối cảnh, vấn đề (boss dễ đoán), ý tưởng, đóng góp.
2. **Cơ sở lý thuyết:** Imitation Learning, Behavior Cloning, compounding error, DAgger. Tóm tắt các công trình liên quan ngắn gọn.
3. **Thiết kế game:** luật, action, kiến trúc Controller, mô phỏng headless.
4. **Phương pháp:**
   - Định nghĩa bài toán (policy π(a|s)).
   - State (mirror hoá), action, tần suất ra quyết định.
   - Pipeline dữ liệu, xử lý mất cân bằng lớp.
   - Kiến trúc mô hình, huấn luyện, tham số độ khó.
5. **Thực nghiệm:**
   - Thiết lập (bot nguyên mẫu, người chơi, số trận, seed).
   - Kết quả: learning curve, similarity, distinctiveness, reaction time.
   - So sánh BC và DAgger, ablation.
   - Khảo sát người chơi.
6. **Thảo luận:** điều học được, lỗi gặp phải và cách xử lý, hạn chế (dữ liệu ít người, action space nhỏ, DAgger chỉ với bot, một nhân vật).
7. **Kết luận và hướng phát triển.**
8. **Phụ lục:** `SPEC.md`, siêu tham số, hướng dẫn chạy lại.

**Mẹo viết:** mỗi biểu đồ nên đi kèm một câu kết luận rõ ràng ("Win-rate bão hoà ở khoảng 5.000 mẫu"), không chỉ chèn hình.

---

## 11. Code mẫu tham khảo

Các đoạn dưới đây là khung để bạn bắt đầu, cần chỉnh theo spec cuối cùng.

### 11.1. Huấn luyện BC (PyTorch)

```python
# ml/train.py (rút gọn)
import json, numpy as np, pandas as pd, torch, torch.nn as nn
from sklearn.model_selection import GroupShuffleSplit

N_STATE, N_ACT = 22, 10

df = pd.read_csv("data/raw/rusher.csv")
X = df[[f"s{i}" for i in range(N_STATE)]].values.astype(np.float32)
y = df["action"].values.astype(np.int64)
groups = df["session_id"].values

# chia theo trận, tránh rò rỉ giữa các frame liền kề
tr, va = next(GroupShuffleSplit(test_size=0.2, random_state=0).split(X, y, groups))
mean, std = X[tr].mean(0), X[tr].std(0) + 1e-6
Xtr, Xva = (X[tr] - mean) / std, (X[va] - mean) / std
ytr, yva = y[tr], y[va]

# trọng số lớp: tỉ lệ nghịch căn bậc hai tần suất
counts = np.bincount(ytr, minlength=N_ACT).astype(np.float32) + 1
w = 1.0 / np.sqrt(counts); w = w / w.mean()

model = nn.Sequential(
    nn.Linear(N_STATE, 64), nn.ReLU(),
    nn.Linear(64, 64), nn.ReLU(),
    nn.Linear(64, N_ACT),
)
loss_fn = nn.CrossEntropyLoss(weight=torch.tensor(w))
opt = torch.optim.Adam(model.parameters(), lr=1e-3)

Xtr_t, ytr_t = torch.tensor(Xtr), torch.tensor(ytr)
Xva_t, yva_t = torch.tensor(Xva), torch.tensor(yva)

best, patience = 1e9, 0
for epoch in range(200):
    model.train()
    perm = torch.randperm(len(Xtr_t))
    for i in range(0, len(perm), 256):
        idx = perm[i:i + 256]
        opt.zero_grad()
        loss_fn(model(Xtr_t[idx]), ytr_t[idx]).backward()
        opt.step()
    model.eval()
    with torch.no_grad():
        vl = loss_fn(model(Xva_t), yva_t).item()
    if vl < best:
        best, patience = vl, 0
        torch.save(model.state_dict(), "data/models/best.pt")
    else:
        patience += 1
        if patience >= 15:
            break

# xuất JSON cho Godot
model.load_state_dict(torch.load("data/models/best.pt"))
layers = [m for m in model if isinstance(m, nn.Linear)]
out = {
    "mean": mean.tolist(), "std": std.tolist(),
    "layers": [{"W": l.weight.detach().tolist(), "b": l.bias.detach().tolist()} for l in layers],
}
json.dump(out, open("data/models/mirror.json", "w"))
```

### 11.2. Forward pass trong GDScript

```gdscript
# game/scripts/mlp.gd
class_name MLP

var layers: Array = []
var mean: Array = []
var std: Array = []

func load_from_json(path: String) -> bool:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return false
    var data = JSON.parse_string(f.get_as_text())
    layers = data["layers"]
    mean = data["mean"]
    std = data["std"]
    return true

func forward(state: PackedFloat32Array) -> PackedFloat32Array:
    var a := PackedFloat32Array()
    a.resize(state.size())
    for i in state.size():
        a[i] = (state[i] - mean[i]) / std[i]

    for li in layers.size():
        var W: Array = layers[li]["W"]   # [out][in]
        var b: Array = layers[li]["b"]
        var out := PackedFloat32Array()
        out.resize(b.size())
        for o in b.size():
            var s: float = b[o]
            var row: Array = W[o]
            for j in a.size():
                s += row[j] * a[j]
            out[o] = s
        if li < layers.size() - 1:       # ReLU cho các lớp ẩn
            for o in out.size():
                out[o] = maxf(out[o], 0.0)
        a = out
    return a                              # logits

func sample_action(logits: PackedFloat32Array, temperature: float) -> int:
    var probs := PackedFloat32Array()
    probs.resize(logits.size())
    var m := -INF
    for v in logits:
        m = maxf(m, v)
    var total := 0.0
    for i in logits.size():
        probs[i] = exp((logits[i] - m) / maxf(temperature, 0.01))
        total += probs[i]
    var r := randf() * total
    var acc := 0.0
    for i in probs.size():
        acc += probs[i]
        if r <= acc:
            return i
    return probs.size() - 1
```

### 11.3. Interface Controller (ý tưởng)

```gdscript
# game/scripts/controllers/controller.gd
class_name Controller

# state: PackedFloat32Array 22 chiều, đã mirror hoá
# trả về action_id (0..9)
func decide(state: PackedFloat32Array) -> int:
    return 0
```

### 11.4. Test khớp GDScript và PyTorch

1. Trong Python, chọn 20 state ngẫu nhiên, lưu `state` và `logits` PyTorch vào `test_vectors.json`.
2. Trong Godot, một scene test nạp `mirror.json` + `test_vectors.json`, chạy `forward` và in sai số lớn nhất.
3. Yêu cầu: sai số tuyệt đối < 1e-4. Chạy test này mỗi khi đổi kiến trúc hoặc spec.

---

## 12. Checklist theo dõi tiến độ

### Nền tảng

- [x] `SPEC.md` hoàn chỉnh và đóng băng (T1)
- [x] Nhân vật di chuyển/nhảy mượt (T1) *(code xong; xác nhận cảm quan/FPS trên máy dev)*
- [x] Luật chiến đấu đầy đủ (T2)
- [x] Interface Controller (T2)
- [x] `state_encoder` có mirror hoá (T2)
- [ ] Chạy headless ổn định (T2) *(chờ chạy `run_matches.ps1` sau khi cài Godot)*

### Dữ liệu & mô hình

- [x] 3 bot nguyên mẫu (T3)
- [x] Data logger (T3)
- [x] `match_runner` chạy hàng loạt trận (T3)
- [x] GDScript khớp PyTorch (T3) *(sai số < 1e-4 trên 20 test vectors)*
- [ ] Dữ liệu ≥ 10.000 mẫu mỗi bot (T4)
- [ ] BC baseline train xong (T4)
- [ ] Dữ liệu ≥ 5 người thật (T6)

### Sản phẩm

- [ ] Luồng luyện tập → Mirror → Gương Đấu (T5)
- [ ] Tham số `reaction_delay`, `temperature` (T5)
- [ ] Rule fallback (T5)
- [ ] Màn hình thống kê hậu trận (T9)
- [ ] Hiệu ứng, âm thanh (T9)
- [ ] Bản build demo (T9)

### Đánh giá

- [ ] Learning curve (T7)
- [ ] KL-divergence / similarity (T7)
- [ ] Ma trận distinctiveness (T7)
- [ ] Reaction time (T7)
- [ ] DAgger vs BC (T8)
- [ ] Ablation (T8)
- [ ] Khảo sát người chơi (T6–T7)

### Bàn giao

- [ ] Báo cáo hoàn chỉnh (T10)
- [ ] Slide + video demo dự phòng (T10)
- [ ] README, hướng dẫn chạy lại (T10)
- [ ] Tập demo ≥ 3 lần (T10)

---

## Gợi ý bước tiếp theo

Việc nên làm ngay trong 2–3 ngày đầu:

1. Chốt `SPEC.md` (action, state, CSV) vì mọi thứ khác phụ thuộc vào nó.
2. Chạy thử một project Godot ở chế độ `--headless` để chắc chắn mô phỏng hàng loạt khả thi.
3. Viết sớm test khớp GDScript và PyTorch bằng một model giả, để loại bỏ rủi ro tích hợp lớn nhất ngay từ tuần đầu.
