extends Node2D
## HUD Chiến đấu phong cách đối kháng hiện đại:
## - Thanh máu vát chéo đối xứng có hiệu ứng tụt máu trễ (damage trail)
## - Chân dung biểu tượng & danh hiệu đấu sĩ
## - Đồng hồ đếm ngược trung tâm + Nhãn chế độ đấu
## - 4 Ô hồi chiêu kỹ năng (Heavy / Kick / Dash / Dodge) hai bên
## - Combo counter nảy động, Banner vào trận / K.O.
## - Bảng trực quan xác suất hành động của AI Mirror theo thời gian thực (phím Tab)

var fight: FightMatch = null
var mode_badge: String = "LUYỆN TẬP"
var sample_count: int = 0
var show_ai_panel: bool = false
var hud_visible_in_menu: bool = false

const ACTION_LABELS_VI: PackedStringArray = [
	"Đứng yên", "Tiến tới", "Lùi lại", "Nhảy", "Đấm nhẹ",
	"Đấm mạnh", "Đá", "Thủ", "Né lùi", "Lướt tới",
]

const CD_SHORT_P1: Array = [
	{"idx": 0, "key": "K", "name": "Mạnh"},
	{"idx": 1, "key": "L", "name": "Đá"},
	{"idx": 2, "key": "E", "name": "Lướt"},
	{"idx": 3, "key": "Q", "name": "Né"},
]

const CD_SHORT_P2: Array = [
	{"idx": 0, "key": "", "name": "Mạnh"},
	{"idx": 1, "key": "", "name": "Đá"},
	{"idx": 2, "key": "", "name": "Lướt"},
	{"idx": 3, "key": "", "name": "Né"},
]

var _trail_hp: PackedFloat32Array = PackedFloat32Array([100.0, 100.0])
var _trail_hold: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _prev_hp: PackedFloat32Array = PackedFloat32Array([100.0, 100.0])

var _combo_display: PackedInt32Array = PackedInt32Array([0, 0])
var _combo_timer: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _combo_pop: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])

var _banner_title: String = ""
var _banner_sub: String = ""
var _banner_col: Color = Color(0.35, 0.88, 1.0, 1.0)
var _banner_age: float = 0.0
var _banner_life: float = 0.0
var _time: float = 0.0


func reset_bars() -> void:
	for i in 2:
		_trail_hp[i] = GameConstants.MAX_HP
		_prev_hp[i] = GameConstants.MAX_HP
		_trail_hold[i] = 0.0
		_combo_display[i] = 0
		_combo_timer[i] = 0.0
		_combo_pop[i] = 0.0


func show_banner(title: String, subtitle: String = "", accent: Color = Color(0.35, 0.88, 1.0, 1.0), duration: float = 1.45) -> void:
	_banner_title = title
	_banner_sub = subtitle
	_banner_col = accent
	_banner_age = 0.0
	_banner_life = duration


func _process(delta: float) -> void:
	_time += delta
	if _banner_life > 0.0:
		_banner_age += delta
		if _banner_age >= _banner_life:
			_banner_life = 0.0

	if fight != null and fight.fighters.size() == 2:
		for i in 2:
			var cur_hp := fight.fighters[i].hp
			if cur_hp < _prev_hp[i] - 0.01:
				_trail_hold[i] = 0.30
			elif cur_hp > _prev_hp[i] + 1.0:
				_trail_hp[i] = cur_hp
			_prev_hp[i] = cur_hp

			if _trail_hold[i] > 0.0:
				_trail_hold[i] -= delta
			else:
				_trail_hp[i] = move_toward(_trail_hp[i], cur_hp, 58.0 * delta)

			var c := fight.fighters[i].combo
			if c >= 2:
				if c != _combo_display[i]:
					_combo_pop[i] = 1.0
				_combo_display[i] = c
				_combo_timer[i] = 0.85
			elif _combo_timer[i] > 0.0:
				_combo_timer[i] = maxf(0.0, _combo_timer[i] - delta)
			_combo_pop[i] = maxf(0.0, _combo_pop[i] - delta * 4.5)

	queue_redraw()


func _draw() -> void:
	if fight == null or fight.fighters.size() < 2 or hud_visible_in_menu:
		return

	var font := ThemeDB.fallback_font
	if font == null:
		return

	var f0 := fight.fighters[0]
	var f1 := fight.fighters[1]

	_draw_top_backdrop()
	_draw_fighter_header(font, f0, true, 0)
	_draw_fighter_header(font, f1, false, 1)
	_draw_center_timer(font)
	_draw_cooldown_strip(font, f0, true)
	_draw_cooldown_strip(font, f1, false)
	_draw_combo_badges(font, f0, f1)
	if show_ai_panel:
		_draw_ai_telemetry(font)
	if _banner_life > 0.0:
		_draw_center_banner(font)
	_draw_bottom_bar(font)


func _draw_top_backdrop() -> void:
	# Dải nền mờ nhẹ phía trên giúp thanh máu luôn nổi bật
	draw_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(1280.0, 0.0),
			Vector2(1280.0, 106.0), Vector2(0.0, 106.0),
		]),
		PackedColorArray([
			Color(0.02, 0.03, 0.08, 0.72),
			Color(0.02, 0.03, 0.08, 0.72),
			Color(0.02, 0.03, 0.08, 0.0),
			Color(0.02, 0.03, 0.08, 0.0),
		])
	)


func _draw_fighter_header(font: Font, f: FighterCharacter, is_left: bool, idx: int) -> void:
	var bar_w := 476.0
	var bar_h := 24.0
	var bar_y := 36.0
	var slant := 12.0

	# Khung chân dung đấu sĩ ở góc ngoài
	var port_c := Vector2(46.0 if is_left else 1234.0, 46.0)
	_draw_portrait_emblem(port_c, f)

	var hp_ratio := clampf(f.hp / GameConstants.MAX_HP, 0.0, 1.0)
	var trail_ratio := clampf(maxf(_trail_hp[idx], f.hp) / GameConstants.MAX_HP, 0.0, 1.0)

	var x_outer := 84.0 if is_left else (1280.0 - 84.0)
	var dir := 1.0 if is_left else -1.0

	# Khung nền thanh máu vát chéo
	var bg_poly := _make_skew_bar(x_outer, bar_y, bar_w, bar_h, slant, dir)
	draw_colored_polygon(bg_poly, Color(0.07, 0.09, 0.16, 0.92))

	# Phần máu tụt trễ (vàng hổ phách sáng)
	if trail_ratio > 0.002:
		var tr_poly := _make_skew_bar(x_outer, bar_y + 2.0, (bar_w - 4.0) * trail_ratio, bar_h - 4.0, slant * 0.85, dir)
		draw_colored_polygon(tr_poly, Color(1.0, 0.82, 0.36, 0.90))

	# Phần máu hiện tại
	if hp_ratio > 0.002:
		var fill_w := (bar_w - 4.0) * hp_ratio
		var fill_poly := _make_skew_bar(x_outer + dir * 2.0, bar_y + 2.0, fill_w, bar_h - 4.0, slant * 0.85, dir)
		var bar_col := f.body_color.lerp(f.accent_color, 0.35)
		if hp_ratio < 0.25:
			var danger := 0.5 + 0.5 * sin(_time * 12.0)
			bar_col = bar_col.lerp(Color(1.0, 0.22, 0.20, 1.0), 0.55 + 0.35 * danger)
		draw_colored_polygon(fill_poly, bar_col)
		# Vệt bóng kính nửa trên thanh máu
		var gloss_poly := _make_skew_bar(x_outer + dir * 2.0, bar_y + 2.0, fill_w, (bar_h - 4.0) * 0.42, slant * 0.4, dir)
		draw_colored_polygon(gloss_poly, Color(1.0, 1.0, 1.0, 0.22))

	# Viền kim loại sắc nét quanh thanh máu
	var border_pts := bg_poly.duplicate()
	border_pts.append(bg_poly[0])
	var border_col := f.accent_color
	border_col.a = 0.82
	draw_polyline(border_pts, border_col, 1.8, true)

	# Tên đấu sĩ, danh hiệu & chỉ số HP
	var hp_txt := "%d / %d" % [int(ceilf(f.hp)), int(GameConstants.MAX_HP)]
	if is_left:
		draw_string_outline(font, Vector2(86.0, 28.0), f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(86.0, 28.0), f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.96, 0.98, 1.0, 1.0))
		var name_w := font.get_string_size(f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(86.0 + name_w + 10.0, 28.0), "• " + f.display_subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, f.accent_color.lightened(0.15))
		draw_string_outline(font, Vector2(84.0 + bar_w - 78.0, 28.0), hp_txt, HORIZONTAL_ALIGNMENT_RIGHT, 76.0, 13, 3, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(84.0 + bar_w - 78.0, 28.0), hp_txt, HORIZONTAL_ALIGNMENT_RIGHT, 76.0, 13, Color(0.92, 0.96, 1.0, 0.95))
	else:
		var right_edge := 1280.0 - 86.0
		draw_string_outline(font, Vector2(right_edge - 260.0, 28.0), f.display_name, HORIZONTAL_ALIGNMENT_RIGHT, 260.0, 15, 3, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(right_edge - 260.0, 28.0), f.display_name, HORIZONTAL_ALIGNMENT_RIGHT, 260.0, 15, Color(0.96, 0.98, 1.0, 1.0))
		var name_w := font.get_string_size(f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var sub_txt := f.display_subtitle + " •"
		draw_string(font, Vector2(right_edge - name_w - 228.0, 28.0), sub_txt, HORIZONTAL_ALIGNMENT_RIGHT, 218.0, 12, f.accent_color.lightened(0.15))
		draw_string_outline(font, Vector2(1280.0 - 84.0 - bar_w + 2.0, 28.0), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, 90.0, 13, 3, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(1280.0 - 84.0 - bar_w + 2.0, 28.0), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, 90.0, 13, Color(0.92, 0.96, 1.0, 0.95))


func _make_skew_bar(x_anchor: float, y: float, w: float, h: float, slant: float, dir: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x_anchor, y),
		Vector2(x_anchor + dir * w, y),
		Vector2(x_anchor + dir * (w - slant), y + h),
		Vector2(x_anchor - dir * slant * 0.25, y + h),
	])


func _draw_portrait_emblem(center: Vector2, f: FighterCharacter) -> void:
	var rad := 26.0
	var hex := PackedVector2Array()
	for i in 6:
		var ang := -PI * 0.5 + float(i) * TAU / 6.0
		hex.append(center + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(hex, Color(0.08, 0.11, 0.20, 0.95))

	# Vẽ đầu & băng trán thu nhỏ trong khung lục giác
	var face_dir := 1.0 if center.x < 640.0 else -1.0
	draw_circle(center + Vector2(0.0, 3.0), 11.5, f.body_color.darkened(0.35))
	draw_circle(center + Vector2(face_dir * 2.0, 3.0), 8.2, Color(0.90, 0.82, 0.76, 1.0) if not f.is_mirror_clone else Color(0.18, 0.22, 0.38, 1.0))
	draw_line(center + Vector2(-10.5, -1.0), center + Vector2(10.5, -1.0), f.accent_color, 4.0, true)
	draw_line(center + Vector2(face_dir * 2.0, 2.5), center + Vector2(face_dir * 7.5, 2.0), Color.WHITE, 2.4, true)

	var outline := hex.duplicate()
	outline.append(hex[0])
	draw_polyline(outline, f.accent_color, 2.2, true)


func _draw_center_timer(font: Font) -> void:
	var cx := 640.0
	var cy := 46.0
	var secs_left := maxi(0, ceili(float(GameConstants.ROUND_TIME_TICKS - fight.tick_count) / float(GameConstants.TARGET_FPS)))
	var urgent := secs_left <= 10 and not fight.finished

	var crest := PackedVector2Array([
		Vector2(cx - 46.0, cy - 26.0),
		Vector2(cx + 46.0, cy - 26.0),
		Vector2(cx + 56.0, cy),
		Vector2(cx + 40.0, cy + 28.0),
		Vector2(cx - 40.0, cy + 28.0),
		Vector2(cx - 56.0, cy),
	])
	draw_colored_polygon(crest, Color(0.06, 0.09, 0.17, 0.96))
	var outline := crest.duplicate()
	outline.append(crest[0])
	var rim := Color(1.0, 0.32, 0.30, 0.95) if urgent else Color(0.42, 0.82, 1.0, 0.88)
	draw_polyline(outline, rim, 2.2, true)

	var t_str := "%02d" % secs_left
	var t_col := Color(1.0, 0.38, 0.34, 1.0) if urgent else Color(0.96, 0.98, 1.0, 1.0)
	draw_string_outline(font, Vector2(cx - 48.0, cy + 10.0), t_str, HORIZONTAL_ALIGNMENT_CENTER, 96.0, 28, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(cx - 48.0, cy + 10.0), t_str, HORIZONTAL_ALIGNMENT_CENTER, 96.0, 28, t_col)

	# Nhãn chế độ nhỏ bên dưới đồng hồ
	var pill := Rect2(cx - 58.0, cy + 33.0, 116.0, 18.0)
	draw_rect(pill, Color(0.07, 0.11, 0.21, 0.88))
	draw_rect(pill, Color(rim.r, rim.g, rim.b, 0.55), false, 1.2)
	draw_string(font, Vector2(cx - 58.0, cy + 46.0), mode_badge, HORIZONTAL_ALIGNMENT_CENTER, 116.0, 11, rim.lightened(0.2))


func _draw_cooldown_strip(font: Font, f: FighterCharacter, is_left: bool) -> void:
	var items := CD_SHORT_P1 if is_left else CD_SHORT_P2
	var pill_w := 86.0
	var pill_h := 22.0
	var gap := 8.0
	var y := 66.0

	for k in items.size():
		var item: Dictionary = items[k]
		var cd_idx: int = item["idx"]
		var ratio := f.cooldown_ratio(cd_idx)
		var ready := ratio <= 0.001
		var x := (84.0 + float(k) * (pill_w + gap)) if is_left else (1280.0 - 84.0 - pill_w - float(k) * (pill_w + gap))
		var r := Rect2(x, y, pill_w, pill_h)

		draw_rect(r, Color(0.06, 0.09, 0.16, 0.88))
		if ready:
			var fill_c := f.accent_color
			fill_c.a = 0.18
			draw_rect(r, fill_c)
			draw_rect(r, Color(f.accent_color.r, f.accent_color.g, f.accent_color.b, 0.78), false, 1.4)
		else:
			var prog := 1.0 - ratio
			draw_rect(Rect2(x, y, pill_w * prog, pill_h), Color(0.25, 0.35, 0.52, 0.45))
			draw_rect(r, Color(0.35, 0.40, 0.52, 0.55), false, 1.1)

		var label := ""
		var key_str: String = item["key"]
		var nm: String = item["name"]
		if not ready:
			var secs := float(f.cooldowns[cd_idx]) / float(GameConstants.TARGET_FPS)
			label = ("%s %.1fs" % [nm, secs])
		else:
			label = ("[%s] %s" % [key_str, nm]) if key_str != "" else nm
		var txt_col := Color(0.95, 0.98, 1.0, 0.96) if ready else Color(0.62, 0.68, 0.78, 0.85)
		draw_string(font, Vector2(x, y + 15.0), label, HORIZONTAL_ALIGNMENT_CENTER, pill_w, 11, txt_col)


func _draw_combo_badges(font: Font, f0: FighterCharacter, f1: FighterCharacter) -> void:
	for i in 2:
		if _combo_timer[i] <= 0.0 or _combo_display[i] < 2:
			continue
		var f := f0 if i == 0 else f1
		var alpha := clampf(_combo_timer[i] * 2.2, 0.0, 1.0)
		var bx := 92.0 if i == 0 else (1280.0 - 252.0)
		var by := 132.0 - _combo_pop[i] * 6.0
		var bw := 160.0
		var bh := 42.0
		var bg := Color(0.06, 0.09, 0.18, 0.82 * alpha)
		draw_rect(Rect2(bx, by, bw, bh), bg)
		var ac := f.accent_color
		ac.a = alpha
		draw_rect(Rect2(bx, by, 4.0 if i == 0 else bw, bh if i == 0 else 3.0), ac)
		var txt := "%d COMBO!" % _combo_display[i]
		draw_string_outline(font, Vector2(bx, by + 27.0), txt, HORIZONTAL_ALIGNMENT_CENTER, bw, 20, 4, Color(0, 0, 0, 0.85 * alpha))
		draw_string(font, Vector2(bx, by + 27.0), txt, HORIZONTAL_ALIGNMENT_CENTER, bw, 20, Color(1.0, 0.92, 0.38, alpha))


func _draw_center_banner(font: Font) -> void:
	var u := clampf(_banner_age / maxf(_banner_life, 0.01), 0.0, 1.0)
	var fade_in := clampf(u / 0.14, 0.0, 1.0)
	var fade_out := clampf((1.0 - u) / 0.24, 0.0, 1.0)
	var a := minf(fade_in, fade_out)
	var cy := 218.0

	draw_rect(Rect2(0.0, cy - 38.0, 1280.0, 78.0), Color(0.03, 0.05, 0.12, 0.78 * a))
	var line_c := _banner_col
	line_c.a = 0.85 * a
	draw_line(Vector2(220.0, cy - 38.0), Vector2(1060.0, cy - 38.0), line_c, 2.2)
	draw_line(Vector2(220.0, cy + 40.0), Vector2(1060.0, cy + 40.0), line_c, 2.2)

	draw_string_outline(font, Vector2(0.0, cy + 4.0), _banner_title, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 34, 6, Color(0, 0, 0, 0.92 * a))
	draw_string(font, Vector2(0.0, cy + 4.0), _banner_title, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 34, Color(1.0, 0.98, 0.94, a))
	if _banner_sub != "":
		draw_string_outline(font, Vector2(0.0, cy + 28.0), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 15, 3, Color(0, 0, 0, 0.85 * a))
		draw_string(font, Vector2(0.0, cy + 28.0), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 15, Color(_banner_col.r, _banner_col.g, _banner_col.b, a))


func _draw_ai_telemetry(font: Font) -> void:
	if fight == null or fight.controllers.size() < 2:
		return
	var mirror_ctrl: MirrorController = null
	var owner_label := "P2"
	if fight.controllers[1] is MirrorController:
		mirror_ctrl = fight.controllers[1] as MirrorController
		owner_label = fight.fighters[1].display_name
	elif fight.controllers[0] is MirrorController:
		mirror_ctrl = fight.controllers[0] as MirrorController
		owner_label = fight.fighters[0].display_name

	var px := 968.0
	var py := 436.0
	var pw := 294.0
	var ph := 238.0
	draw_rect(Rect2(px, py, pw, ph), Color(0.04, 0.07, 0.15, 0.88))
	draw_rect(Rect2(px, py, pw, ph), Color(0.42, 0.82, 1.0, 0.65), false, 1.5)

	draw_string(font, Vector2(px + 12.0, py + 20.0), "AI BRAIN • " + owner_label, HORIZONTAL_ALIGNMENT_LEFT, pw - 24.0, 13, Color(0.55, 0.92, 1.0, 1.0))

	if mirror_ctrl == null or not mirror_ctrl.is_loaded() or mirror_ctrl.last_probs.size() != GameConstants.N_ACTIONS:
		draw_string(font, Vector2(px + 12.0, py + 48.0), "Đối thủ hiện tại là Bot luật (Rule-based).", HORIZONTAL_ALIGNMENT_LEFT, pw - 24.0, 12, Color(0.75, 0.80, 0.90, 0.85))
		draw_string(font, Vector2(px + 12.0, py + 68.0), "Chọn phím 4..8 hoặc 9 để xem mạng MLP!", HORIZONTAL_ALIGNMENT_LEFT, pw - 24.0, 12, Color(0.65, 0.85, 1.0, 0.85))
		return

	var probs := mirror_ctrl.last_probs
	var chosen := mirror_ctrl.last_action
	for i in GameConstants.N_ACTIONS:
		var ry := py + 32.0 + float(i) * 20.0
		var p := probs[i]
		var is_sel := (i == chosen)
		var lbl_col := Color(0.98, 0.95, 0.55, 1.0) if is_sel else Color(0.80, 0.86, 0.94, 0.90)
		draw_string(font, Vector2(px + 12.0, ry + 11.0), ACTION_LABELS_VI[i], HORIZONTAL_ALIGNMENT_LEFT, 82.0, 11, lbl_col)

		var bx := px + 96.0
		var bw := 146.0
		draw_rect(Rect2(bx, ry + 1.0, bw, 11.0), Color(0.10, 0.14, 0.24, 0.9))
		var bar_c := Color(0.45, 0.94, 1.0, 0.95) if is_sel else Color(0.36, 0.58, 0.88, 0.78)
		draw_rect(Rect2(bx, ry + 1.0, bw * clampf(p, 0.0, 1.0), 11.0), bar_c)
		draw_string(font, Vector2(bx + bw + 6.0, ry + 11.0), "%d%%" % int(roundf(p * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, 36.0, 11, lbl_col)


func _draw_bottom_bar(font: Font) -> void:
	var y := 688.0
	draw_rect(Rect2(0.0, y, 1280.0, 32.0), Color(0.03, 0.05, 0.11, 0.84))
	draw_line(Vector2(0.0, y), Vector2(1280.0, y), Color(0.32, 0.62, 0.92, 0.35), 1.0)

	var left_hint := "A/D: Di chuyển · W: Nhảy · J: Đấm nhẹ · K: Đấm mạnh · L: Đá · S: Thủ · Q: Né · E: Lướt"
	draw_string(font, Vector2(18.0, y + 21.0), left_hint, HORIZONTAL_ALIGNMENT_LEFT, 780.0, 12, Color(0.82, 0.88, 0.96, 0.92))

	var right_info := "Mẫu đã ghi: %d  |  [Tab] AI Brain · [F2] Hitbox · [R] Đấu lại · [Esc] Menu" % sample_count
	draw_string(font, Vector2(760.0, y + 21.0), right_info, HORIZONTAL_ALIGNMENT_RIGHT, 502.0, 12, Color(0.55, 0.88, 1.0, 0.95))
