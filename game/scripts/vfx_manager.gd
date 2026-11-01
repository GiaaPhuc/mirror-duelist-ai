class_name VfxManager
extends Node2D
## Quản lý toàn bộ hiệu ứng chiến đấu (Hit sparks, sóng xung kích, khiên chắn,
## số sát thương bay lên, bụi chân, tàn ảnh Dash/Dodge/Mirror và rung Camera).

var _sparks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _dusts: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []
var _mirror_wisps: Array[Dictionary] = []

var _shake_trauma: float = 0.0
var _flash_alpha: float = 0.0
var _flash_color: Color = Color.WHITE
var _rng := RandomNumberGenerator.new()
var _back_layer: Node2D = null


class BackVfxCanvas extends Node2D:
	var manager: VfxManager = null
	func _draw() -> void:
		if manager != null:
			manager._draw_back_layer(self)


func _ready() -> void:
	_rng.randomize()
	z_as_relative = false
	z_index = 6

	_back_layer = BackVfxCanvas.new()
	_back_layer.manager = self
	_back_layer.z_as_relative = false
	_back_layer.z_index = 1
	add_child(_back_layer)


func clear_all() -> void:
	_sparks.clear()
	_rings.clear()
	_texts.clear()
	_dusts.clear()
	_ghosts.clear()
	_mirror_wisps.clear()
	_shake_trauma = 0.0
	_flash_alpha = 0.0
	queue_redraw()
	if _back_layer != null:
		_back_layer.queue_redraw()


func add_trauma(amount: float) -> void:
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.0)


func trigger_flash(col: Color, alpha: float = 0.35) -> void:
	_flash_color = col
	_flash_alpha = maxf(_flash_alpha, alpha)


func spawn_dust(world_pos: Vector2, dir_x: float = 0.0, count: int = 5, tint: Color = Color(0.72, 0.84, 0.98, 1.0)) -> void:
	for i in count:
		var vx := -dir_x * _rng.randf_range(35.0, 105.0) + _rng.randf_range(-38.0, 38.0)
		var vy := _rng.randf_range(-48.0, -12.0)
		_dusts.append({
			"pos": world_pos + Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-3.0, 1.0)),
			"vel": Vector2(vx, vy),
			"r": _rng.randf_range(3.5, 7.5),
			"age": 0.0,
			"life": _rng.randf_range(0.24, 0.42),
			"col": tint,
		})


func spawn_afterimage(f: FighterCharacter, col_override: Color = Color(0, 0, 0, 0)) -> void:
	var ghost_col := col_override
	if ghost_col.a <= 0.001:
		ghost_col = f.accent_color
		ghost_col.a = 0.46 if not f.is_mirror_clone else 0.56
	var pose := FighterRenderer.compute_pose(f, f.anim_time)
	_ghosts.append({
		"pos": f.position,
		"pose": pose,
		"col": ghost_col,
		"age": 0.0,
		"life": 0.22,
	})


func spawn_mirror_wisp(f: FighterCharacter) -> void:
	_mirror_wisps.append({
		"pos": f.position + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-50.0, -8.0)),
		"vel": Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-42.0, -20.0)),
		"r": _rng.randf_range(1.6, 3.2),
		"age": 0.0,
		"life": _rng.randf_range(0.35, 0.65),
		"col": f.accent_color.lightened(0.25),
	})


func spawn_hit_effect(
	impact_pos: Vector2,
	damage: float,
	action: int,
	attacker_accent: Color,
	combo: int,
	is_ko: bool
) -> void:
	var is_heavy := action == GameConstants.ACTION_HEAVY or damage >= 12.0
	var is_kick := action == GameConstants.ACTION_KICK
	var spark_count := 22 if is_ko else (18 if is_heavy else (14 if is_kick else 10))
	var base_col := Color(1.0, 0.72, 0.22, 1.0) if is_heavy else attacker_accent.lightened(0.2)

	for i in spark_count:
		var ang := _rng.randf_range(0.0, TAU)
		var spd := _rng.randf_range(130.0, 390.0 if is_heavy else 280.0)
		_sparks.append({
			"pos": impact_pos,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"len": _rng.randf_range(9.0, 20.0 if is_heavy else 14.0),
			"age": 0.0,
			"life": _rng.randf_range(0.16, 0.32),
			"col": base_col if i % 3 != 0 else Color(1.0, 0.98, 0.88, 1.0),
		})

	_rings.append({
		"pos": impact_pos,
		"r0": 6.0,
		"r1": 68.0 if is_ko else (50.0 if is_heavy else 34.0),
		"age": 0.0,
		"life": 0.28 if is_ko else 0.20,
		"col": base_col,
		"width": 3.6 if is_heavy else 2.4,
		"hex": false,
	})
	if is_heavy or is_ko:
		_rings.append({
			"pos": impact_pos,
			"r0": 4.0,
			"r1": 88.0 if is_ko else 32.0,
			"age": 0.0,
			"life": 0.34 if is_ko else 0.16,
			"col": Color(1.0, 0.96, 0.82, 1.0),
			"width": 2.2,
			"hex": false,
		})

	var dmg_str := "-%d" % int(roundf(damage))
	if combo >= 2:
		dmg_str += "  (%dx)" % combo
	_texts.append({
		"pos": impact_pos + Vector2(_rng.randf_range(-10.0, 10.0), -14.0),
		"vel": Vector2(_rng.randf_range(-18.0, 18.0), -82.0),
		"text": dmg_str,
		"size": 22 if is_heavy else 17,
		"col": Color(1.0, 0.84, 0.28, 1.0) if is_heavy else Color(1.0, 0.96, 0.92, 1.0),
		"age": 0.0,
		"life": 0.68,
	})

	if is_ko:
		add_trauma(0.85)
		trigger_flash(Color(1.0, 0.92, 0.80, 1.0), 0.42)
	elif is_heavy:
		add_trauma(0.52)
		trigger_flash(base_col, 0.14)
	elif is_kick:
		add_trauma(0.32)
	else:
		add_trauma(0.18)


func spawn_block_effect(impact_pos: Vector2, chip_damage: float) -> void:
	var shield_col := Color(0.38, 0.92, 1.0, 1.0)
	for i in 9:
		var ang := _rng.randf_range(0.0, TAU)
		var spd := _rng.randf_range(90.0, 210.0)
		_sparks.append({
			"pos": impact_pos,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"len": _rng.randf_range(7.0, 12.0),
			"age": 0.0,
			"life": _rng.randf_range(0.14, 0.24),
			"col": shield_col,
		})

	_rings.append({
		"pos": impact_pos,
		"r0": 8.0,
		"r1": 34.0,
		"age": 0.0,
		"life": 0.22,
		"col": shield_col,
		"width": 2.6,
		"hex": true,
	})

	_texts.append({
		"pos": impact_pos + Vector2(0.0, -16.0),
		"vel": Vector2(0.0, -56.0),
		"text": "CHẮN! (-%.0f)" % maxf(1.0, chip_damage),
		"size": 14,
		"col": Color(0.58, 0.95, 1.0, 1.0),
		"age": 0.0,
		"life": 0.52,
	})
	add_trauma(0.14)


func update_camera(cam: Camera2D, base_pos: Vector2, delta: float) -> void:
	if cam == null:
		return
	if _shake_trauma > 0.001:
		var amt := _shake_trauma * _shake_trauma
		var ox := _rng.randf_range(-1.0, 1.0) * 14.0 * amt
		var oy := _rng.randf_range(-1.0, 1.0) * 10.0 * amt
		cam.position = base_pos + Vector2(ox, oy)
		_shake_trauma = maxf(0.0, _shake_trauma - delta * 2.8)
	else:
		cam.position = base_pos


func _process(delta: float) -> void:
	_step_list_sparks(delta)
	_step_list_rings(delta)
	_step_list_texts(delta)
	_step_list_dusts(delta)
	_step_list_ghosts(delta)
	_step_list_wisps(delta)
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 2.4)
	queue_redraw()
	if _back_layer != null:
		_back_layer.queue_redraw()


func _step_list_sparks(delta: float) -> void:
	var i := _sparks.size() - 1
	while i >= 0:
		var s: Dictionary = _sparks[i]
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) >= float(s["life"]):
			_sparks.remove_at(i)
		else:
			var vel: Vector2 = s["vel"]
			s["pos"] = (s["pos"] as Vector2) + vel * delta
			s["vel"] = vel * pow(0.08, delta)
		i -= 1


func _step_list_rings(delta: float) -> void:
	var i := _rings.size() - 1
	while i >= 0:
		var r: Dictionary = _rings[i]
		r["age"] = float(r["age"]) + delta
		if float(r["age"]) >= float(r["life"]):
			_rings.remove_at(i)
		i -= 1


func _step_list_texts(delta: float) -> void:
	var i := _texts.size() - 1
	while i >= 0:
		var t: Dictionary = _texts[i]
		t["age"] = float(t["age"]) + delta
		if float(t["age"]) >= float(t["life"]):
			_texts.remove_at(i)
		else:
			var vel: Vector2 = t["vel"]
			t["pos"] = (t["pos"] as Vector2) + vel * delta
			t["vel"] = Vector2(vel.x * 0.94, vel.y + 110.0 * delta)
		i -= 1


func _step_list_dusts(delta: float) -> void:
	var i := _dusts.size() - 1
	while i >= 0:
		var d: Dictionary = _dusts[i]
		d["age"] = float(d["age"]) + delta
		if float(d["age"]) >= float(d["life"]):
			_dusts.remove_at(i)
		else:
			var vel: Vector2 = d["vel"]
			d["pos"] = (d["pos"] as Vector2) + vel * delta
			d["vel"] = vel * pow(0.2, delta)
			d["r"] = float(d["r"]) + delta * 12.0
		i -= 1


func _step_list_ghosts(delta: float) -> void:
	var i := _ghosts.size() - 1
	while i >= 0:
		var g: Dictionary = _ghosts[i]
		g["age"] = float(g["age"]) + delta
		if float(g["age"]) >= float(g["life"]):
			_ghosts.remove_at(i)
		i -= 1


func _step_list_wisps(delta: float) -> void:
	var i := _mirror_wisps.size() - 1
	while i >= 0:
		var w: Dictionary = _mirror_wisps[i]
		w["age"] = float(w["age"]) + delta
		if float(w["age"]) >= float(w["life"]):
			_mirror_wisps.remove_at(i)
		else:
			w["pos"] = (w["pos"] as Vector2) + (w["vel"] as Vector2) * delta
		i -= 1


func _draw_back_layer(canvas: CanvasItem) -> void:
	# Tàn ảnh bóng mờ (Afterimages)
	for g in _ghosts:
		var ratio := 1.0 - float(g["age"]) / float(g["life"])
		var col: Color = g["col"]
		col.a *= ratio
		var pos: Vector2 = g["pos"]
		var pose: Dictionary = g["pose"]
		var hip: Vector2 = pos + (pose["hip"] as Vector2)
		var shoulder: Vector2 = pos + (pose["shoulder"] as Vector2)
		var head: Vector2 = pos + (pose["head"] as Vector2)
		var foot_f: Vector2 = pos + (pose["foot_f"] as Vector2)
		var foot_b: Vector2 = pos + (pose["foot_b"] as Vector2)
		var hand_f: Vector2 = pos + (pose["hand_f"] as Vector2)
		canvas.draw_line(hip, shoulder, col, 9.5, true)
		canvas.draw_circle(head, 5.8, col)
		canvas.draw_line(hip, foot_f, col, 5.2, true)
		canvas.draw_line(hip, foot_b, col, 4.8, true)
		canvas.draw_line(shoulder, hand_f, col, 4.8, true)

	# Hạt linh quang Gương Đấu
	for w in _mirror_wisps:
		var ratio := sin(clampf(float(w["age"]) / float(w["life"]), 0.0, 1.0) * PI)
		var col: Color = w["col"]
		col.a = 0.65 * ratio
		var p: Vector2 = w["pos"]
		var r: float = w["r"]
		canvas.draw_colored_polygon(PackedVector2Array([
			p + Vector2(0.0, -r * 1.4),
			p + Vector2(r, 0.0),
			p + Vector2(0.0, r * 1.4),
			p + Vector2(-r, 0.0),
		]), col)

	# Bụi chân trên mặt sàn
	for d in _dusts:
		var ratio := 1.0 - float(d["age"]) / float(d["life"])
		var col: Color = d["col"]
		col.a = 0.34 * ratio
		canvas.draw_circle(d["pos"], float(d["r"]), col)


func _draw() -> void:
	# Vòng sóng xung kích & khiên lục giác
	for r in _rings:
		var u := clampf(float(r["age"]) / float(r["life"]), 0.0, 1.0)
		var rad := lerpf(float(r["r0"]), float(r["r1"]), 1.0 - pow(1.0 - u, 2.5))
		var col: Color = r["col"]
		col.a = (1.0 - u) * 0.90
		var center: Vector2 = r["pos"]
		if bool(r["hex"]):
			var pts := PackedVector2Array()
			for k in 7:
				var ang := float(k) * TAU / 6.0
				pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
			draw_polyline(pts, col, float(r["width"]), true)
		else:
			draw_arc(center, rad, 0.0, TAU, 32, col, float(r["width"]) * (1.0 - u * 0.5), true)

	# Tia lửa trúng đòn
	for s in _sparks:
		var u := clampf(float(s["age"]) / float(s["life"]), 0.0, 1.0)
		var pos: Vector2 = s["pos"]
		var vel: Vector2 = s["vel"]
		var dir := vel.normalized() if vel.length_squared() > 0.01 else Vector2.RIGHT
		var tail := pos - dir * float(s["len"]) * (1.0 - u * 0.5)
		var col: Color = s["col"]
		col.a = 1.0 - u
		draw_line(tail, pos, col, 2.6 * (1.0 - u * 0.4), true)

	# Số sát thương bay lên
	var font := ThemeDB.fallback_font
	if font != null:
		for t in _texts:
			var u := clampf(float(t["age"]) / float(t["life"]), 0.0, 1.0)
			var col: Color = t["col"]
			col.a = clampf(1.35 - u * 1.35, 0.0, 1.0)
			var txt: String = t["text"]
			var sz: int = t["size"]
			var p: Vector2 = t["pos"]
			draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, sz, 4, Color(0.03, 0.04, 0.09, col.a * 0.92))
			draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, sz, col)

	# Chớp sáng màn hình (Impact / K.O. Flash)
	if _flash_alpha > 0.005:
		var fc := _flash_color
		fc.a = _flash_alpha
		draw_rect(Rect2(-800.0, -120.0, 1600.0, 960.0), fc)
