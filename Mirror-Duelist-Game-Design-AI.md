# Mirror Duelist
### Game đối kháng 2D với AI học phong cách chiến đấu của người chơi

---

## 1. Tổng quan ý tưởng

**Concept một dòng:** Một game fighting 2D nơi "boss cuối" không được lập trình sẵn — nó là một AI học chính phong cách chiến đấu của người chơi trong suốt quá trình chơi, rồi quay lại đấu với chính người chơi bằng lối đánh đó.

**Câu chuyện trải nghiệm:**
1. Người chơi luyện tập, đấu tay đôi với các đối thủ thường trong nhiều trận.
2. Mọi hành động của người chơi (combo dùng nhiều, khoảng cách ưa thích, thời điểm né đòn, xu hướng tấn công/phòng thủ) được ghi lại.
3. Đến "Gương Đấu" (Mirror Arena), một bản sao AI xuất hiện — đánh đúng phong cách của người chơi, nhưng phản xạ nhanh hơn và ít mắc lỗi hơn.
4. Người chơi buộc phải **nhận ra và phá vỡ chính thói quen của mình** để chiến thắng — đây là lõi cảm xúc độc đáo của game: đối thủ khó nhất không phải là ai khác mà là chính bạn.

---

## 2. Gameplay chính

| Thành phần | Mô tả |
|---|---|
| Thể loại | Fighting game 2D, đối kháng 1vs1, góc nhìn ngang (side-view) |
| Action cơ bản | Đấm nhẹ, đấm mạnh, đá, nhảy, né (dodge), thủ (block), dash tới/lùi |
| Vòng lặp chính | Luyện tập (thu thập dữ liệu) → Gương Đấu (đối đầu AI) → Rút kinh nghiệm → Luyện tập tiếp |
| Progression | Mỗi "phiên bản gương" là một checkpoint: AI càng học nhiều dữ liệu, càng khó đối phó → tạo động lực chơi tiếp để "vượt qua chính mình phiên bản trước" |
| Yếu tố khác biệt so với fighting game thường | Không có bảng combo cố định để học thuộc — chiến thắng đến từ việc **linh hoạt thay đổi phong cách**, vì AI luôn bắt kịp phong cách cũ của bạn |

---

## 3. Vai trò của AI — vấn đề thực sự được giải quyết

**Vấn đề trong game đối kháng truyền thống:** Boss AI thường được lập trình bằng finite state machine hoặc behavior tree cố định → dễ đoán, chơi vài lần là thuộc pattern, mất hứng thú.

**Mirror Duelist giải quyết bằng cách:** để AI **học trực tiếp từ dữ liệu hành vi thật của người chơi** (thay vì thiết kế tay), khiến:
- Mỗi người chơi có một "đối thủ cuối" hoàn toàn khác nhau (không ai giống ai).
- AI luôn thách thức đúng điểm yếu/thói quen của người chơi đó — cá nhân hoá độ khó một cách tự nhiên.
- Đây là bài toán học thuật thật: **Imitation Learning / Behavior Cloning** — được nghiên cứu nhiều trong robotics và game AI, có nhiều tài liệu tham khảo.

---

## 4. Thiết kế kỹ thuật AI

### 4.1. Định nghĩa bài toán
Học một hàm chính sách (policy) π(a | s) ánh xạ từ trạng thái trận đấu sang hành động, sao cho phân phối hành động của π gần giống với phân phối hành động thật của người chơi trong các trạng thái tương tự.

### 4.2. State space (đầu vào của AI) — đề xuất ~12-15 chiều
- Khoảng cách ngang/dọc tới đối thủ
- HP của bản thân và đối thủ (chuẩn hoá 0-1)
- Cooldown còn lại của từng skill (đấm mạnh, đá, dash...)
- Trạng thái hiện tại của đối thủ (đang tấn công / đang thủ / đang rảnh / đang hồi chiêu)
- Hướng nhìn (trái/phải) của cả hai
- Vận tốc hiện tại (đang di chuyển tới/lùi/đứng yên)
- Số hit liên tiếp gần nhất (combo counter)

### 4.3. Action space (đầu ra) — 6-8 hành động rời rạc
`{đấm_nhẹ, đấm_mạnh, đá, nhảy, né, thủ, dash_tới, dash_lùi}`

Action space rời rạc + nhỏ giúp bài toán dễ học và dễ đánh giá hơn nhiều so với continuous action space.

### 4.4. Kiến trúc mô hình (giai đoạn MVP)
- **Baseline:** Mạng MLP 2-3 lớp ẩn (ví dụ 64-64 units, ReLU), đầu ra là phân phối xác suất trên action space (softmax) → huấn luyện bằng cross-entropy loss theo kiểu supervised learning (Behavior Cloning).
- **Input:** state vector đã chuẩn hoá.
- **Output:** action được chọn (argmax hoặc sampling có nhiệt độ để tạo độ ngẫu nhiên tự nhiên, tránh AI quá máy móc).

### 4.5. Nâng cấp (nếu còn thời gian, không bắt buộc cho MVP)
- **DAgger (Dataset Aggregation):** giảm lỗi tích luỹ (compounding error) đặc trưng của behavior cloning thuần — cho AI tự chơi, gán nhãn thêm bằng cách hỏi "người chơi thật sẽ làm gì trong tình huống này", rồi retrain.
- **GAIL (Generative Adversarial Imitation Learning):** dùng discriminator để phân biệt hành vi AI vs. người thật, huấn luyện AI qua RL để "đánh lừa" discriminator → hành vi tự nhiên hơn, ít bị overfit vào đúng dữ liệu quan sát được.
- **Reward shaping nhẹ:** thêm một phần thưởng nhỏ để AI không chỉ bắt chước mà còn "tối ưu hơn một chút" (ví dụ ưu tiên né khi HP thấp) — giữ trận đấu công bằng và có thử thách.

---

## 5. Pipeline thu thập dữ liệu & huấn luyện

```
[Người chơi đấu với AI luyện tập/dummy]
        │  (ghi log mỗi frame quyết định)
        ▼
[Dataset: state, action] — CSV/JSON, mục tiêu 5.000–10.000+ mẫu
        │
        ▼
[Huấn luyện Behavior Cloning bằng PyTorch]
        │
        ▼
[Export model → ONNX]
        │
        ▼
[Import vào Game Engine (Unity Barracuda / Godot qua ONNX runtime)]
        │
        ▼
[AI "Mirror" đấu lại người chơi trong Gương Đấu]
```

**Nguồn dữ liệu:**
- Tự chơi nhiều phiên với nhiều phong cách khác nhau (rush, phòng thủ, poke...) để có dữ liệu đa dạng.
- Nhờ 3-5 người bạn/bạn học chơi thử để có nhiều "chữ ký phong cách" khác nhau — mỗi người sẽ tạo ra một AI Mirror khác nhau, dùng để so sánh trong báo cáo.

---

## 6. Đánh giá hiệu quả AI bằng số liệu cụ thể

| Chỉ số | Ý nghĩa | Cách đo |
|---|---|---|
| **Win-rate theo learning curve** | AI học tốt tới đâu khi dữ liệu tăng dần | Train với 1k / 5k / 10k mẫu, cho đấu N trận với chính người tạo dữ liệu, vẽ đồ thị win-rate |
| **Behavioral similarity** | AI có thực sự "giống" người chơi không | So sánh phân phối hành động của AI và người trong các state tương tự bằng KL-divergence hoặc cosine similarity |
| **Reaction time** | AI phản ứng nhanh hơn người bao nhiêu | Đo thời gian từ khi state thay đổi (ví dụ đối thủ tấn công) đến khi AI phản ứng (né/thủ), so với thời gian phản ứng trung bình của người |
| **Action distribution match** | Tần suất dùng từng skill có khớp với người không | So sánh histogram tần suất action giữa AI và người trên cùng bộ trận đấu |
| **Cross-player distinctiveness** | Mỗi AI Mirror có thực sự khác nhau giữa các người chơi khác nhau không | Train AI riêng cho 3-5 người, so sánh similarity giữa các AI này — kỳ vọng thấp (mỗi AI khác biệt rõ) |
| **Compounding error (nếu có DAgger)** | Behavior cloning thuần có bị lệch dần theo thời gian trận đấu không | So sánh độ lệch hành vi ở giây đầu trận vs. giây cuối trận giữa bản BC thuần và bản có DAgger |

---

## 7. Công nghệ đề xuất

| Thành phần | Công cụ |
|---|---|
| Game Engine | **Godot 4** (nhẹ, miễn phí, export nhanh) hoặc **Unity** (nếu cần Barracuda/ML-Agents có sẵn) |
| Huấn luyện AI | Python + **PyTorch** (mạng MLP nhỏ, dễ debug, huấn luyện nhanh trên CPU) |
| Thu thập dữ liệu | Script logging ngay trong engine, xuất CSV/JSON |
| Inference trong game | **ONNX Runtime** (Unity Barracuda) hoặc server Python nhẹ (FastAPI) giao tiếp qua socket nếu dùng Godot |
| Trực quan hoá kết quả | Matplotlib/Seaborn để vẽ learning curve, biểu đồ phân phối hành vi cho báo cáo |
| Quản lý mã nguồn | Git + GitHub (dùng luôn cho portfolio) |

---

## 8. Độ khó & tính khả thi

- **Độ khó:** 6/7
- **Khả thi trong 2–3 tháng cho 1 sinh viên:** Có — miễn giới hạn action space nhỏ (6-8 hành động), state space gọn (~12-15 chiều), và bắt đầu bằng Behavior Cloning thuần (bỏ qua DAgger/GAIL cho tới khi MVP chạy ổn).
- **Rủi ro chính:**
  - Compounding error của Behavior Cloning thuần (AI có thể "lạc" khỏi phân phối dữ liệu huấn luyện trong trận thật) → giải pháp: giới hạn combat đơn giản, có thể thêm rule an toàn (fallback) khi AI gặp state lạ.
  - Dữ liệu không đủ đa dạng nếu chỉ một người chơi tạo ra → nên thu thập từ nhiều người/nhiều phong cách.
  - Tích hợp ONNX vào engine cần thời gian làm quen ban đầu — nên test pipeline này sớm (tuần 1-2) để tránh rủi ro về sau.

---

## 9. Lộ trình triển khai đề xuất (8–10 tuần)

**Tuần 1–2 — Nền tảng game**
- Dựng cơ chế fighting 2D tối giản: 1 nhân vật, 6-8 action, hitbox/hurtbox cơ bản, 1 map nhỏ.
- Định nghĩa rõ ràng state vector và action space (xem mục 4.2, 4.3).
- Test sớm pipeline ONNX import vào engine (dùng model giả/random để kiểm tra kỹ thuật trước).

**Tuần 3–4 — Thu thập dữ liệu & huấn luyện baseline**
- Ghi log (state, action) khi người chơi đấu với AI rule-based đơn giản (dummy đối thủ).
- Thu thập 5.000–10.000+ mẫu từ nhiều phiên chơi, nhiều phong cách, nhiều người nếu có thể.
- Huấn luyện MLP bằng PyTorch (Behavior Cloning baseline).

**Tuần 5–6 — Tích hợp AI vào game**
- Export model sang ONNX, import vào engine.
- Test AI "Mirror" đấu với chính người tạo dữ liệu — kiểm tra định tính AI có "giống" không.

**Tuần 7–8 — Đánh giá & tinh chỉnh**
- Đo learning curve (win-rate theo lượng dữ liệu: 1k/5k/10k mẫu).
- Đo behavioral similarity (KL-divergence phân phối action).
- (Nếu còn thời gian) thử DAgger hoặc reward shaping nhẹ để cải thiện.

**Tuần 9–10 — Polish & viết báo cáo**
- Hoàn thiện UI, hiệu ứng, âm thanh, hiệu ứng "Gương Đấu" (visual để nhấn mạnh AI là bản sao của người chơi).
- Viết báo cáo: mô tả bài toán, phương pháp, thực nghiệm, biểu đồ kết quả, thảo luận hạn chế và hướng phát triển.

---

## 10. Điểm nhấn khi trình bày / demo cho hội đồng

1. **Demo trực tiếp:** cho hội đồng tự chơi vài phút, sau đó cho họ đấu với "Mirror" của chính họ — hiệu ứng bất ngờ rất mạnh khi họ nhận ra AI đang "đọc vị" đúng thói quen của mình.
2. **Biểu đồ learning curve** cho thấy rõ AI học tốt hơn theo lượng dữ liệu — bằng chứng định lượng thuyết phục.
3. **So sánh 2-3 AI Mirror** được train từ 2-3 người chơi khác nhau, chỉ ra chúng có phong cách khác biệt rõ rệt — chứng minh AI thực sự học đặc trưng cá nhân chứ không học một pattern chung chung.
4. **Kể câu chuyện cải tiến:** "Ban đầu tôi dùng Behavior Cloning thuần, gặp vấn đề compounding error ở tình huống X, tôi giải quyết bằng cách Y" — cho thấy tư duy nghiên cứu, không chỉ là lắp ráp công cụ có sẵn.

---

## 11. Hướng mở rộng nếu làm tiếp sau đồ án

- Thêm nhiều nhân vật, mỗi nhân vật có state/action space riêng.
- Huấn luyện AI Mirror qua nhiều trận (không chỉ 1 lần) để mô phỏng "quá trình trưởng thành" của AI theo thời gian.
- Chế độ nhiều người chơi: Mirror của người A đấu với Mirror của người B — xem AI nào "phản chiếu" người chơi giỏi hơn thắng.
- Thêm giải thích trực quan (explainability) — hiển thị cho người chơi thấy AI đang "nghĩ" gì (ví dụ heatmap xác suất action) để tăng giá trị giáo dục của sản phẩm.
