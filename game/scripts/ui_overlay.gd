class_name UiOverlay
extends Control
## Giao diện Menu Chính ("MIRROR DUELIST") và Bảng Thống Kê Phong Cách Hậu Trận.
## Hỗ trợ đầy đủ cả click chuột trực quan lẫn phím tắt bàn phím.

signal mode_selected(mode_id: String)
signal resume_requested()
signal rematch_requested()
signal open_menu_requested()

enum ScreenMode { NONE, MAIN_MENU, POST_MATCH }

var screen_mode: ScreenMode = ScreenMode.MAIN_MENU
var can_resume: bool = false
var total_human_samples: int = 0
var current_mode_id: String = "rusher"
var summary_data: Dictionary = {}

var _buttons: Array[Dictionary] = []
var _hovered_id: String = ""
var _anim_t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_rebuild_buttons()


func set_screen(mode: ScreenMode) -> void:
	screen_mode = mode
	_hovered_id = ""
	mouse_filter = Control.MOUSE_FILTER_STOP if mode != ScreenMode.NONE else Control.MOUSE_FILTER_IGNORE
	_rebuild_buttons()
	queue_redraw()


func show_post_match(stats: Dictionary) -> void:
	summary_data = stats
	set_screen(ScreenMode.POST_MATCH)


func _process(delta: float) -> void:
	_anim_t += delta
	if screen_mode != ScreenMode.NONE:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if screen_mode == ScreenMode.NONE:
		return
	if event is InputEventMouseMotion:
		var mp: Vector2 = (event as InputEventMouseMotion).position
		var found := ""
		for b in _buttons:
			if (b["rect"] as Rect2).has_point(mp):
				found = str(b["id"])
				break
		if found != _hovered_id:
			_hovered_id = found
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			for b in _buttons:
				if (b["rect"] as Rect2).has_point(mb.position):
					_activate_button(str(b["id"]))
					accept_event()
					return


func _activate_button(btn_id: String) -> void:
	if btn_id == "resume":
		emit_signal("resume_requested")
	elif btn_id == "rematch":
		emit_signal("rematch_requested")
	elif btn_id == "menu":
		emit_signal("open_menu_requested")
	else:
		emit_signal("mode_selected", btn_id)


func _rebuild_buttons() -> void:
	_buttons.clear()
	if screen_mode == ScreenMode.MAIN_MENU:
		# Cột 1: Luyện tập Bot (x = 76, w = 356)
		var col1_x := 76.0
		var card_w := 356.0
		var bots := [
			{"id": "rusher", "key": "1", "title": "Bot Rusher", "desc": "Áp sát dồn dập, liên hoàn đấm & đá", "col": Color(1.0, 0.52, 0.22)},
			{"id": "turtle", "key": "2", "title": "Bot Turtle", "desc": "Phòng thủ kiên cố, chờ sơ hở phản đòn", "col": Color(0.28, 0.92, 0.68)},
			{"id": "poker", "key": "3", "title": "Bot Poker", "desc": "Giữ khoảng cách, tỉa máu tầm xa bằng cước", "col": Color(0.92, 0.45, 0.88)},
			{"id": "random", "key": "0", "title": "Bot Random", "desc": "Hành động ngẫu nhiên — làm quen nút bấm", "col": Color(0.95, 0.80, 0.32)},
		]
		for i in bots.size():
			var b: Dictionary = bots[i]
			_buttons.append({
				"id": b["id"],
				"key": b["key"],
				"title": b["title"],
				"desc": b["desc"],
				"col": b["col"],
				"rect": Rect2(col1_x, 232.0 + float(i) * 76.0, card_w, 64.0),
			})

		# Cột 2: Gương Đấu AI Mirror (x = 462, w = 356)
		var col2_x := 462.0
		var mirrors := [
			{"id": "mirror_self", "key": "8", "title": "★ Mirror-Self (Bản Sao Của Bạn)", "desc": "AI học trực tiếp từ dữ liệu chiến đấu của bạn", "col": Color(0.42, 0.92, 1.0)},
			{"id": "mirror", "key": "4", "title": "Mirror Chuẩn", "desc": "Bản sao Behavior Cloning mặc định (mirror.json)", "col": Color(0.65, 0.56, 1.0)},
			{"id": "mirror_rusher", "key": "5", "title": "Mirror-Rusher", "desc": "Mạng MLP học phong cách tấn công của Rusher", "col": Color(1.0, 0.56, 0.36)},
			{"id": "mirror_turtle", "key": "6", "title": "Mirror-Turtle", "desc": "Mạng MLP học phong cách phòng thủ của Turtle", "col": Color(0.38, 0.92, 0.75)},
			{"id": "mirror_poker", "key": "7", "title": "Mirror-Poker", "desc": "Mạng MLP học phong cách giữ cự ly của Poker", "col": Color(0.92, 0.52, 0.92)},
		]
		for i in mirrors.size():
			var m: Dictionary = mirrors[i]
			_buttons.append({
				"id": m["id"],
				"key": m["key"],
				"title": m["title"],
				"desc": m["desc"],
				"col": m["col"],
				"rect": Rect2(col2_x, 232.0 + float(i) * 68.0, card_w, 58.0),
			})

		# Cột 3: Quan sát AI & Tiếp tục (x = 848, w = 356)
		var col3_x := 848.0
		_buttons.append({
			"id": "watch",
			"key": "9",
			"title": "Xem AI Đấu Nhau (Mirror vs Bot)",
			"desc": "Quan sát trực quan độ giống giữa AI và Bot gốc",
			"col": Color(0.52, 0.86, 1.0),
			"rect": Rect2(col3_x, 232.0, card_w, 68.0),
		})
		if can_resume:
			_buttons.append({
				"id": "resume",
				"key": "Esc",
				"title": "Tiếp Tục Trận Đang Đấu",
				"desc": "Quay lại sàn đấu ngay lập tức",
				"col": Color(0.35, 0.95, 0.62),
				"rect": Rect2(col3_x, 312.0, card_w, 60.0),
			})

	elif screen_mode == ScreenMode.POST_MATCH:
		var by := 564.0
		_buttons.append({
			"id": "rematch",
			"key": "R",
			"title": "Đấu Lại Ngay",
			"desc": "",
			"col": Color(0.35, 0.92, 0.65),
			"rect": Rect2(260.0, by, 235.0, 48.0),
		})
		var is_watch := bool(summary_data.get("watch_mode", false))
		_buttons.append({
			"id": "watch" if is_watch else "mirror_self",
			"key": "9" if is_watch else "8",
			"title": "Cặp AI Tiếp Theo" if is_watch else "Đấu Mirror-Self",
			"desc": "",
			"col": Color(0.45, 0.88, 1.0),
			"rect": Rect2(515.0, by, 250.0, 48.0),
		})
		_buttons.append({
			"id": "menu",
			"key": "Esc",
			"title": "Menu Đối Thủ",
			"desc": "",
			"col": Color(0.75, 0.62, 1.0),
			"rect": Rect2(785.0, by, 235.0, 48.0),
		})


func _draw() -> void:
	if screen_mode == ScreenMode.NONE:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return

	if screen_mode == ScreenMode.MAIN_MENU:
		_draw_main_menu(font)
	elif screen_mode == ScreenMode.POST_MATCH:
		_draw_post_match(font)


func _draw_main_menu(font: Font) -> void:
	# Lớp phủ mờ sang trọng để vẫn thấy Đền Gương & 2 võ sĩ biểu diễn phía sau
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.02, 0.03, 0.09, 0.74))

	# Tiêu đề chính MIRROR DUELIST
	var glow_a := 0.55 + 0.25 * sin(_anim_t * 2.5)
	draw_line(Vector2(340.0, 48.0), Vector2(940.0, 48.0), Color(0.38, 0.84, 1.0, 0.35 * glow_a), 1.5)
	draw_string_outline(font, Vector2(0.0, 92.0), "MIRROR DUELIST", HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 44, 6, Color(0.03, 0.06, 0.16, 0.95))
	draw_string(font, Vector2(0.0, 92.0), "MIRROR DUELIST", HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 44, Color(0.92, 0.97, 1.0, 1.0))

	var sub := "ĐẤU TRƯỜNG ÁNH GƯƠNG  •  KHI ĐỐI THỦ KHÓ NHẤT LÀ CHÍNH BẠN"
	draw_string(font, Vector2(0.0, 120.0), sub, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 14, Color(0.48, 0.88, 1.0, 0.92))

	# Thanh trạng thái dữ liệu học hành vi của người chơi
	var badge_rect := Rect2(310.0, 138.0, 660.0, 38.0)
	draw_rect(badge_rect, Color(0.06, 0.10, 0.20, 0.90))
	draw_rect(badge_rect, Color(0.35, 0.78, 1.0, 0.55), false, 1.4)
	var status_note := "Đã sẵn sàng cho Gương Đấu!" if total_human_samples >= 500 else "Đấu với Bot để tự động thu thập phong cách chiến đấu của bạn"
	var sample_str := "Dữ liệu hành vi của bạn (human_self.csv): %d mẫu  •  %s" % [total_human_samples, status_note]
	draw_string(font, Vector2(310.0, 162.0), sample_str, HORIZONTAL_ALIGNMENT_CENTER, 660.0, 13, Color(0.86, 0.95, 1.0, 0.96))

	# Tiêu đề 3 cột
	_draw_section_header(font, 76.0, 206.0, 356.0, "1. LUYỆN TẬP & GHI DỮ LIỆU", Color(1.0, 0.65, 0.28))
	_draw_section_header(font, 462.0, 206.0, 356.0, "2. GƯƠNG ĐẤU (AI HỌC HÀNH VI)", Color(0.45, 0.90, 1.0))
	_draw_section_header(font, 848.0, 206.0, 356.0, "3. CHẾ ĐỘ XEM & ĐIỀU KHIỂN", Color(0.72, 0.60, 1.0))

	# Vẽ các thẻ bấm
	for b in _buttons:
		_draw_card_button(font, b, false)

	# Khung hướng dẫn phím điều khiển ở nửa dưới cột 3
	var help_y := 388.0 if can_resume else 318.0
	var help_h := 564.0 - help_y
	var hr := Rect2(848.0, help_y, 356.0, help_h)
	draw_rect(hr, Color(0.05, 0.08, 0.16, 0.88))
	draw_rect(hr, Color(0.32, 0.52, 0.78, 0.48), false, 1.2)
	draw_string(font, Vector2(864.0, help_y + 24.0), "BẢNG PHÍM CHIẾN ĐẤU", HORIZONTAL_ALIGNMENT_LEFT, 324.0, 13, Color(0.55, 0.88, 1.0, 1.0))

	var controls := [
		["A / D  hoặc  ← / →", "Di chuyển tiến / lùi"],
		["W  hoặc  Space", "Nhảy vượt đòn"],
		["J  /  K  /  L", "Đấm nhẹ / Đấm mạnh / Đá"],
		["S  hoặc  ↓", "Giương khiên chắn (-80% ST)"],
		["Q  /  E", "Né lùi (i-frame) / Lướt tới"],
		["Tab  /  F2", "Xem não AI (MLP) / Hitbox"],
	]
	for idx in controls.size():
		var cy := help_y + 48.0 + float(idx) * 26.0
		if cy + 10.0 > help_y + help_h:
			break
		draw_string(font, Vector2(864.0, cy), controls[idx][0], HORIZONTAL_ALIGNMENT_LEFT, 145.0, 12, Color(0.98, 0.90, 0.52, 0.95))
		draw_string(font, Vector2(1012.0, cy), controls[idx][1], HORIZONTAL_ALIGNMENT_LEFT, 184.0, 12, Color(0.82, 0.88, 0.96, 0.90))

	draw_string(
		font,
		Vector2(0.0, 682.0),
		"Mẹo: Nhấn chuột vào bất kỳ chế độ nào hoặc bấm phím số [1..9, 0] để vào trận ngay!",
		HORIZONTAL_ALIGNMENT_CENTER,
		1280.0,
		13,
		Color(0.68, 0.82, 0.96, 0.85)
	)


func _draw_section_header(font: Font, x: float, y: float, w: float, title: String, col: Color) -> void:
	draw_string(font, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, w, 14, col)
	draw_line(Vector2(x, y + 8.0), Vector2(x + w, y + 8.0), Color(col.r, col.g, col.b, 0.45), 1.6)


func _draw_card_button(font: Font, b: Dictionary, compact: bool) -> void:
	var r: Rect2 = b["rect"]
	var bid: String = b["id"]
	var hovered := (bid == _hovered_id)
	var col: Color = b["col"]

	var bg := Color(0.11, 0.17, 0.30, 0.96) if hovered else Color(0.06, 0.09, 0.18, 0.90)
	draw_rect(r, bg)
	# Thanh màu điểm nhấn bên trái
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y), col)
	var border_a := 0.95 if hovered else 0.45
	draw_rect(r, Color(col.r, col.g, col.b, border_a), false, 2.0 if hovered else 1.2)

	# Nhãn phím tắt
	var key_str: String = b["key"]
	var kb_w := 34.0
	var kb_y := (r.position.y + (r.size.y - 22.0) * 0.5) if (compact or str(b["desc"]) == "") else (r.position.y + 10.0)
	var kb_rect := Rect2(r.position.x + r.size.x - kb_w - 10.0, kb_y, kb_w, 22.0)
	draw_rect(kb_rect, Color(col.r, col.g, col.b, 0.22 if hovered else 0.14))
	draw_rect(kb_rect, Color(col.r, col.g, col.b, 0.70), false, 1.0)
	draw_string(font, Vector2(kb_rect.position.x, kb_rect.position.y + 15.0), key_str, HORIZONTAL_ALIGNMENT_CENTER, kb_w, 11, col.lightened(0.25))

	if compact or str(b["desc"]) == "":
		draw_string(font, Vector2(r.position.x + 14.0, r.position.y + 30.0), str(b["title"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56.0, 15, Color(0.96, 0.98, 1.0, 1.0))
	else:
		draw_string(font, Vector2(r.position.x + 16.0, r.position.y + 24.0), str(b["title"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 62.0, 15, Color(0.97, 0.99, 1.0, 1.0))
		draw_string(font, Vector2(r.position.x + 16.0, r.position.y + 45.0), str(b["desc"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 12, Color(0.72, 0.80, 0.92, 0.92))


func _draw_post_match(font: Font) -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.02, 0.03, 0.08, 0.72))

	var panel := Rect2(220.0, 86.0, 840.0, 548.0)
	draw_rect(panel, Color(0.05, 0.08, 0.16, 0.95))
	var accent: Color = summary_data.get("banner_color", Color(0.42, 0.88, 1.0, 1.0))
	draw_rect(panel, Color(accent.r, accent.g, accent.b, 0.78), false, 2.2)
	draw_rect(Rect2(panel.position.x, panel.position.y, panel.size.x, 5.0), accent)

	var headline: String = summary_data.get("headline", "KẾT THÚC TRẬN ĐẤU")
	var subline: String = summary_data.get("subline", "")
	draw_string_outline(font, Vector2(panel.position.x, panel.position.y + 48.0), headline, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 32, 5, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 48.0), headline, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 32, accent.lightened(0.2))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 74.0), subline, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, Color(0.82, 0.88, 0.96, 0.92))

	var p1_name: String = summary_data.get("p1_name", "NGƯỜI CHƠI")
	var p2_name: String = summary_data.get("p2_name", "ĐỐI THỦ")
	var p1_col: Color = summary_data.get("p1_col", Color(0.25, 0.85, 1.0))
	var p2_col: Color = summary_data.get("p2_col", Color(0.95, 0.52, 0.36))

	# Tiêu đề đối xứng 2 đấu sĩ
	draw_line(Vector2(256.0, 92.0 + 78.0), Vector2(1024.0, 92.0 + 78.0), Color(0.3, 0.45, 0.68, 0.4), 1.2)
	draw_string(font, Vector2(260.0, 196.0), p1_name, HORIZONTAL_ALIGNMENT_LEFT, 280.0, 16, p1_col.lightened(0.15))
	var sim_pct: float = float(summary_data.get("similarity_pct", 0.0))
	var dist_px: float = float(summary_data.get("avg_dist", 0.0))
	var mid_badge := "Cự ly TB: %.0f px  •  Độ tương đồng phong cách: %.0f%%" % [dist_px, sim_pct]
	draw_string(font, Vector2(440.0, 196.0), mid_badge, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 13, Color(0.96, 0.88, 0.48, 0.95))
	draw_string(font, Vector2(740.0, 196.0), p2_name, HORIZONTAL_ALIGNMENT_RIGHT, 280.0, 16, p2_col.lightened(0.15))

	# Bảng 4 chỉ số chiến đấu cốt lõi
	var metrics: Array = summary_data.get("metrics", [])
	for idx in metrics.size():
		var m: Dictionary = metrics[idx]
		var ry := 226.0 + float(idx) * 28.0
		draw_rect(Rect2(260.0, ry - 16.0, 760.0, 24.0), Color(0.08, 0.12, 0.22, 0.55 if idx % 2 == 0 else 0.25))
		draw_string(font, Vector2(276.0, ry), str(m["p1"]), HORIZONTAL_ALIGNMENT_LEFT, 160.0, 14, Color(0.95, 0.98, 1.0, 0.96))
		draw_string(font, Vector2(480.0, ry), str(m["label"]), HORIZONTAL_ALIGNMENT_CENTER, 320.0, 13, Color(0.72, 0.80, 0.92, 0.92))
		draw_string(font, Vector2(844.0, ry), str(m["p2"]), HORIZONTAL_ALIGNMENT_RIGHT, 160.0, 14, Color(0.95, 0.98, 1.0, 0.96))

	# Biểu đồ thanh đối xứng so sánh phân phối hành động (Phong cách chiến đấu)
	draw_string(
		font,
		Vector2(260.0, 356.0),
		"SO SÁNH TẦN SUẤT HÀNH ĐỘNG (CHỮ KÝ PHONG CÁCH CHIẾN ĐẤU)",
		HORIZONTAL_ALIGNMENT_CENTER,
		760.0,
		13,
		Color(0.55, 0.88, 1.0, 0.95)
	)

	var dist_rows: Array = summary_data.get("dist_rows", [])
	for idx in dist_rows.size():
		var row: Dictionary = dist_rows[idx]
		var ry := 382.0 + float(idx) * 28.0
		var p1_r := clampf(float(row["p1_pct"]) / 100.0, 0.0, 1.0)
		var p2_r := clampf(float(row["p2_pct"]) / 100.0, 0.0, 1.0)
		var max_bar := 220.0

		# Cột tên nhóm hành động ở giữa (x = 560..720)
		draw_string(font, Vector2(555.0, ry + 12.0), str(row["name"]), HORIZONTAL_ALIGNMENT_CENTER, 170.0, 12, Color(0.88, 0.92, 0.98, 0.95))

		# Thanh trái (P1: mở từ 548 sang trái)
		draw_rect(Rect2(548.0 - max_bar, ry + 1.0, max_bar, 13.0), Color(0.09, 0.13, 0.23, 0.9))
		draw_rect(Rect2(548.0 - max_bar * p1_r, ry + 1.0, max_bar * p1_r, 13.0), p1_col)
		draw_string(font, Vector2(548.0 - max_bar - 48.0, ry + 12.0), "%.0f%%" % float(row["p1_pct"]), HORIZONTAL_ALIGNMENT_RIGHT, 42.0, 12, p1_col.lightened(0.2))

		# Thanh phải (P2: mở từ 732 sang phải)
		draw_rect(Rect2(732.0, ry + 1.0, max_bar, 13.0), Color(0.09, 0.13, 0.23, 0.9))
		draw_rect(Rect2(732.0, ry + 1.0, max_bar * p2_r, 13.0), p2_col)
		draw_string(font, Vector2(732.0 + max_bar + 6.0, ry + 12.0), "%.0f%%" % float(row["p2_pct"]), HORIZONTAL_ALIGNMENT_LEFT, 46.0, 12, p2_col.lightened(0.2))

	# 3 nút hành động phía dưới
	for b in _buttons:
		_draw_card_button(font, b, true)
