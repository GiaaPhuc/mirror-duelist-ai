# Báo cáo Tuần 4: Thu thập dữ liệu & Huấn luyện Behavior Cloning Baseline

## 1. Thống kê tập dữ liệu thu thập (`data/raw/*.csv`)

| Nguồn dữ liệu | File CSV | Số phiên (`session_id`) | Tổng số mẫu (10 Hz, actionable) | Train / Val (80/20 theo phiên) | Đối thủ đa dạng |
| --- | --- | ---: | ---: | ---: | --- |
| **Bot Rusher** | `data/raw/rusher.csv` | 249 (199/50) | **10,522** | 8,487 / 2,035 | Turtle, Poker, Rusher, Random |
| **Bot Turtle** | `data/raw/turtle.csv` | 36 (29/7) | **10,761** | 8,914 / 1,847 | Turtle, Poker, Rusher, Random |
| **Bot Poker** | `data/raw/poker.csv` | 120 (96/24) | **10,551** | 8,379 / 2,172 | Turtle, Poker, Rusher, Random |
| **Human Self (`human_self`)** | `data/raw/human_self.csv` | 15 (12/3) | **3,570** | 2,824 / 746 | Rusher, Turtle, Poker, Random (15 phiên) |

---

## 2. Kết quả huấn luyện Behavior Cloning Baseline (MLP `22 -> 64 -> 64 -> 10`)

- **Thiết lập:** Chia `train/val` 80/20 theo `session_id` (0% rò rỉ frame giữa các trận), chuẩn hoá `mean/std` tính trên tập train, hàm mất mát **Weighted Cross-Entropy** ($w_c \propto 1/\sqrt{N_c}$), tối ưu **Adam** (`lr = 1e-3`, `batch_size = 256`), **Early Stopping** (`patience = 15`).
- **Lưu ý về Macro-F1:** Do mỗi bot có $\epsilon = 12\%$ hành động khám phá ngẫu nhiên đều trên 10 hành động, các hành động không thuộc bộ bài chiến thuật của bot (ví dụ Rusher không nhảy hoặc đi lùi theo luật) vẫn xuất hiện ~1.2% trong tập validation như nhiễu ngẫu nhiên. Vì vậy báo cáo trình bày cả **Macro-F1 (toàn bộ 10 lớp)**, **Active Macro-F1 (các hành động chủ đạo $\ge 2.5\%$)** và **Weighted-F1**.

| Model Mirror | Majority Baseline (`maj_acc`) | Val Accuracy (`val_acc`) | Độ vượt trội (`+Δ Acc`) | Macro-F1 (10 lớp) | Active Macro-F1 | Weighted-F1 | Val Loss | Sai số GDScript (`max_abs_err`) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **Mirror-Rusher** (`mirror_rusher.json`) | 35.58% (`light`) | **85.36%** | **+49.78%** | 0.4531 | **0.8437** | 0.8329 | 1.1941 | `1.53e-05` (< 1e-4) |
| **Mirror-Turtle** (`mirror_turtle.json`) | 40.99% (`idle`) | **80.73%** | **+39.74%** | 0.4178 | **0.7252** | 0.7847 | 1.3133 | `3.81e-06` (< 1e-4) |
| **Mirror-Poker** (`mirror_poker.json`) | 31.91% (`walk_fwd`) | **84.35%** | **+52.44%** | 0.5776 | **0.8251** | 0.8282 | 1.1055 | `7.63e-06` (< 1e-4) |
| **Mirror-HumanSelf** (`mirror_human_self.json`) | 31.90% (`block`) | **85.52%** | **+53.62%** | 0.6467 | **0.8256** | 0.8477 | 0.9685 | `2.29e-05` (< 1e-4) |

---

## 3. Đánh giá trực quan & hành vi khi đấu thật (`Mirror-X` vs `Bot-X`, 100 trận/cặp)

| Cặp đấu (100 trận) | Win-rate Mirror | Win-rate Bot gốc | Tỉ lệ Hoà | Khoảng cách TB (`px`) | KL-Divergence $D_{\text{KL}}(\text{Bot} \parallel \text{Mirror})$ | TV Distance |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Mirror-Rusher vs Bot Rusher** | 68.0% | 31.0% | 1.0% | 61.9 px | **0.0414** | 0.0790 |
| **Mirror-Turtle vs Bot Turtle** | 12.0% | 12.0% | 76.0% | 214.7 px | **0.0170** | 0.0508 |
| **Mirror-Poker vs Bot Poker** | 57.0% | 36.0% | 7.0% | 113.4 px | **0.0101** | 0.0328 |

### 3.1. Ma trận phân biệt phong cách chéo (Cross-Style KL-Divergence Matrix)

| Model \ Nguồn đối chiếu | Bot Rusher | Bot Turtle | Bot Poker |
| --- | ---: | ---: | ---: |
| **Mirror-Rusher** | **0.0414** | 2.4840 | 1.4100 |
| **Mirror-Turtle** | 2.2713 | **0.0170** | 1.1477 |
| **Mirror-Poker** | 1.9277 | 0.7885 | **0.0101** |

> **Nhận xét:** Đường chéo chính có giá trị KL-divergence thấp nhất rõ rệt (`0.010 - 0.041` so với `0.78 - 2.48` ngoài đường chéo), chứng tỏ mỗi model Mirror thực sự học đúng "chữ ký phong cách" của bot nguồn chứ không học một chiến thuật trung bình chung.

### 3.2. Quan sát trực quan lần đầu: `Mirror-Rusher` đấu `Rusher` thật

- **Nhịp độ & khoảng cách:** Ngay từ đầu hiệp (`tick = 0`, khoảng cách `240 px`), cả `Mirror-Rusher` và `Bot Rusher` đều lập tức kích hoạt `dash_fwd` (`action=9`) kết hợp `walk_fwd` (`action=1`) để thu hẹp khoảng cách về sát nhau (`61.9 px`).
- **Tần suất ra đòn:** Ở tầm cận chiến, `Mirror-Rusher` ưu tiên tung chuỗi `light` liên hoàn (`46.4%` so với `47.0%` của Bot Rusher), nối combo `heavy` (`13.6%` so với `13.8%`), và lao tới bằng `dash_fwd` (`15.6%`). Nhìn bằng mắt thường trong `main.tscn` (phím `9`), hai nhân vật lao vào đôi công nhịp độ cao hệt như hai bản sao.
- **Đặc trưng `Mirror-Turtle` và `Mirror-Poker`:** Ngược lại, `Mirror-Turtle` giữ khoảng cách xa (`214.7 px`), ưu tiên `idle` + `walk_back` + `block`; trong khi `Mirror-Poker` giữ cự ly tầm trung (`113.4 px`), liên tục bước vào tầm `kick` (`20.3%`) rồi lùi (`walk_back` `8.2%`) hoặc né (`dodge` `5.3%`).

---

## 4. Ghi nhận các lỗi hành vi của BC thuần (Nguyên liệu cho Tuần 5 & Tuần 8)

Qua quan sát trực tiếp trận đấu và đo đạc định lượng (100 trận cùng kiểu + 30 trận chịu áp lực bị Rusher dồn góc), mô hình Behavior Cloning (BC) thuần bộc lộ **3 nhóm lỗi hành vi đặc trưng**:

| Model Mirror | Lỗi 1: Bị ép góc & đi lùi/né vào tường (`|x| >= 490 px`) | Lỗi 2: Đánh hụt ngoài tầm (`dist > 125 px`) / Spam $\ge 3$ đòn | Lỗi 3: Gọi chiêu đang Cooldown (đứng khựng) / Đứng yên (`idle >= 3`) | State lệch phân phối (`|z| > 3.0`) |
| --- | ---: | ---: | ---: | ---: |
| **Mirror-Rusher** | Ở góc: 0.00% (**0.0%** vẫn `walk_back`/`dodge`) | Đánh xa: **0.03%** / Spam: **4.53%** | Cooldown no-op: **0.23%** / Đứng yên: **0.00%** | 11.93% |
| **Mirror-Turtle** | Ở góc: 27.38% (**19.0%** vẫn `walk_back`/`dodge`) | Đánh xa: **4.23%** / Spam: **0.00%** | Cooldown no-op: **1.01%** / Đứng yên: **52.93%** | 8.07% |
| **Mirror-Poker** | Ở góc: 29.22% (**23.6%** vẫn `walk_back`/`dodge`) | Đánh xa: **1.03%** / Spam: **0.10%** | Cooldown no-op: **0.81%** / Đứng yên: **0.14%** | 4.99% |

### Phân tích nguyên nhân & hướng khắc phục (Roadmap Tuần 5 & Tuần 8):

1. **Kẹt ở tường / tiếp tục đi lùi khi đã chạm mép sân (`Corner Wall-Walking`):**
   - *Hiện tượng:* Khi `Mirror-Turtle` hoặc `Mirror-Poker` bị `Rusher` ép sát về hai đầu sân (`|x| >= 490 px`), AI vẫn liên tục chọn `walk_back` (`action=2`) hoặc `dodge` (`action=8`) để giữ khoảng cách (`> 50%` số nhịp ở góc). Do vướng tường, vận tốc thực tế bị kẹp về `0`, khiến nhân vật bị kẹt ở góc và nhận chuỗi đòn.
   - *Nguyên nhân:* State vector v1 (22 chiều) chỉ mã hoá khoảng cách tương đối `s[0] = (opp.x - me.x) * facing / MAP_WIDTH` mà **chưa có khoảng cách tới tường sau lưng**.
   - *Hướng giải quyết:* Thêm **Rule an toàn (Fallback)** ở Tuần 5 (khi sát tường và bị áp sát thì ưu tiên `block` / `dash_fwd` thoát góc), và thử nghiệm mở rộng state v2 (thêm khoảng cách tới tường) ở Tuần 8.

2. **Đứng ngẩn ra (`Idle Stalling` & `Cooldown No-op`) khi rơi vào trạng thái bị động hoặc lấy mẫu trúng chiêu đang hồi:**
   - *Hiện tượng:* Khi `Mirror-Turtle` đấu `Turtle` ở cự ly `~220 px`, cả hai bên giữ trạng thái `idle` kéo dài (`52.9%` số nhịp là chuỗi đứng yên $\ge 3$ quyết định liên tiếp, dẫn đến `76%` trận kết thúc do hết giờ). Ngoài ra, khoảng `0.2% - 1.0%` quyết định chọn kỹ năng (`heavy`/`kick`/`dash`/`dodge`) khi `cooldown > 0`, làm `apply_action()` bỏ qua và nhân vật đứng khựng 6 frame.
   - *Hướng giải quyết:* Ở Tuần 5, triển khai **Rule an toàn (Fallback)** trong `mirror_controller.gd` (nếu đứng xa quá lâu hoặc state ngoài phân phối quen thuộc thì chủ động `walk_fwd` tiến lại gần hoặc `block`), đồng thời giảm/mask xác suất các kỹ năng đang hồi chiêu.

3. **Spam một đòn đánh hoặc tung đòn ngoài tầm với (`Attack Spamming & Out-of-Range Whiffs`):**
   - *Hiện tượng:* `Mirror-Rusher` có `4.53%` tổng số nhịp quyết định lặp lại cùng một đòn tấn công $\ge 3$ lần liên tiếp ở rìa hitbox; trong khi `Mirror-Turtle` và `Mirror-Poker` đôi lúc tung `kick`/`heavy` ở cự ly `> 125 px` do lấy mẫu softmax ở `temperature = 0.7` trên trọng số lớp `1/sqrt(count)`.
   - *Hướng giải quyết:* Thực hiện **DAgger** với bot expert và **Ablation Study** (`temperature = 0.3 / 0.7 / 1.0`, thêm `previous_action` vào state) ở Tuần 8.
