# Mirror Duelist — Đặc tả kỹ thuật (nguồn sự thật)

> **Đóng băng sau Tuần 1.** Mọi thay đổi action/state/CSV yêu cầu thu thập lại dữ liệu huấn luyện.

## Action space (10 hành động rời rạc)

| ID | Tên | Ghi chú |
|----|-----|---------|
| 0 | `idle` | Đứng yên |
| 1 | `walk_fwd` | Đi về phía đối thủ |
| 2 | `walk_back` | Đi lùi |
| 3 | `jump` | Nhảy |
| 4 | `light` | Đấm nhẹ |
| 5 | `heavy` | Đấm mạnh (cooldown) |
| 6 | `kick` | Đá (cooldown) |
| 7 | `block` | Thủ |
| 8 | `dodge` | Né/lướt lùi, i-frames ngắn (cooldown) |
| 9 | `dash_fwd` | Lao tới (cooldown) |

Hằng số: `N_ACTIONS = 10`, `ACTION_NAMES` theo bảng trên.

## State vector (22 chiều, mirror theo góc nhìn bản thân)

| Chỉ số | Nội dung | Chiều | Chuẩn hoá |
|--------|----------|-------|-----------|
| 0 | Khoảng cách ngang có dấu (dương = đối thủ ở phía trước) | 1 | ÷ `MAP_WIDTH` |
| 1 | Chênh lệch độ cao | 1 | ÷ `MAP_MAX_HEIGHT` |
| 2–3 | HP bản thân, HP đối thủ | 2 | 0–1 |
| 4–7 | Cooldown: heavy, kick, dash, dodge | 4 | 0–1 |
| 8–12 | Trạng thái bản thân one-hot: idle / attacking / blocking / stunned / airborne | 5 | one-hot |
| 13–17 | Trạng thái đối thủ (cùng 5 loại) | 5 | one-hot |
| 18–19 | Vận tốc ngang bản thân, đối thủ (hướng “tới trước”) | 2 | ÷ `MAX_RUN_SPEED` |
| 20 | Combo counter | 1 | ÷ 5, clamp 1 |
| 21 | Thời gian từ đòn trúng gần nhất | 1 | ÷ 3 s, clamp 1 |

Hằng số: `N_STATE = 22`.

**Mirror:** không dùng trái/phải tuyệt đối; khoảng cách và vận tốc đối thủ được phản chiếu theo hướng nhìn của nhân vật đang encode.

## CSV (1 dòng = 1 quyết định @ 10 Hz)

```text
session_id,player_id,tick,s0,s1,...,s21,action
```

- `session_id`: một ID mỗi trận (chia train/val theo trận).
- `player_id`: phân biệt người chơi / bot / mirror.
- Chỉ ghi khi nhân vật **actionable** (không stunned, không giữa animation đòn).

## Làm rõ luật chiến đấu (Tuần 2, không đổi action/state/CSV)

- Mô phỏng theo tick cố định 60 Hz; hitbox là hình chữ nhật so với hurtbox thân 28×56 px.
- Frame data (startup/active/recovery tick): light 4/3/8, heavy 12/4/20, kick 8/4/14. Giá trị đầy đủ nằm trong `MOVES` của `game_constants.gd`.
- Cooldown (tick): heavy 60, kick 40, dash 60, dodge 90. Dash 12 tick; dodge 20 tick, i-frames tick 1–10.
- Block giảm 80% sát thương, chỉ chặn đòn từ phía trước. Đòn trúng gây hitstun + đẩy lùi.
- HP 100. Trận 60 s (3600 tick); kết thúc khi KO hoặc hết giờ (so HP, bằng nhau là hoà).
- Decision: người chơi mỗi tick, bot/model 10 Hz. Walk/block giữ đến quyết định tiếp theo.
- State s1 = (y bản thân − y đối thủ)/320, dương nghĩa là đối thủ ở cao hơn.
- "Attacking" (s8–s17) gồm cả light/heavy/kick, dash và dodge.
- s21: thời gian từ lần có đòn trúng gần nhất, tính cả đòn trúng lẫn bị trúng.

## Tham số AI (inference)

| Tham số | Mặc định |
|---------|----------|
| `reaction_delay_ms` | 100 |
| `temperature` | 0.7 |
| `decision_hz` | 10 |

## Mô hình (ML)

- MLP: 22 → 64 → 64 → 10, ReLU, softmax (train PyTorch; inference JSON + forward GDScript).

## Hằng số vật lý / map (game)

| Hằng số | Giá trị |
|---------|---------|
| `MAP_WIDTH` | 960 px |
| `MAP_MAX_HEIGHT` | 320 px |
| `MAX_RUN_SPEED` | 240 px/s |
| `GRAVITY` | 980 px/s² |
| `JUMP_VELOCITY` | -420 px/s |
| `TARGET_FPS` | 60 |
| `DECISION_INTERVAL_FRAMES` | 6 (= 10 Hz @ 60 FPS) |
