extends Node2D
## Phong cảnh Đền Gương Huyền Bí (Mirror Shrine):
## Bầu trời đêm sao, nhật thực ánh gương, dãy núi mờ sương, Đại Gương Cổ trung tâm,
## tinh thể lơ lửng, cột đá ấn ký hai bên và mặt sàn cẩm thạch phản chiếu bóng thật 2 đấu sĩ.

const FLOOR_THICKNESS := 24.0
const WALL_THICKNESS := 36.0

var fighters: Array[FighterCharacter] = []
var mirror_realm_active: bool = false
var _time: float = 0.0

var _stars: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _far_mountains: PackedVector2Array = PackedVector2Array()
var _near_mountains: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_init_scenery_data()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _init_scenery_data() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261101

	_stars.clear()
	for i in 58:
		_stars.append({
			"pos": Vector2(rng.randf_range(-680.0, 680.0), rng.randf_range(-20.0, 340.0)),
			"r": rng.randf_range(0.8, 2.1),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(1.2, 3.4),
		})

	_shards.clear()
	var shard_xs := [-435.0, -355.0, -270.0, -185.0, 185.0, 270.0, 355.0, 435.0, -475.0, 475.0]
	for i in shard_xs.size():
		var sx: float = shard_xs[i]
		_shards.append({
			"base": Vector2(sx, rng.randf_range(145.0, 315.0)),
			"w": rng.randf_range(7.0, 14.0),
			"h": rng.randf_range(18.0, 36.0),
			"phase": rng.randf_range(0.0, TAU),
			"tilt": rng.randf_range(-0.28, 0.28),
		})

	_motes.clear()
	for i in 28:
		_motes.append({
			"x": rng.randf_range(-560.0, 560.0),
			"y": rng.randf_range(90.0, 515.0),
			"vy": rng.randf_range(8.0, 22.0),
			"amp": rng.randf_range(6.0, 18.0),
			"phase": rng.randf_range(0.0, TAU),
			"r": rng.randf_range(1.2, 2.6),
			"warm": i % 4 == 0,
		})

	var floor_y := GameConstants.ARENA_FLOOR_Y
	_far_mountains = PackedVector2Array([
		Vector2(-740.0, floor_y),
		Vector2(-740.0, 370.0),
		Vector2(-610.0, 305.0),
		Vector2(-490.0, 352.0),
		Vector2(-365.0, 278.0),
		Vector2(-240.0, 345.0),
		Vector2(-135.0, 312.0),
		Vector2(0.0, 362.0),
		Vector2(140.0, 308.0),
		Vector2(255.0, 348.0),
		Vector2(380.0, 272.0),
		Vector2(505.0, 350.0),
		Vector2(620.0, 300.0),
		Vector2(740.0, 368.0),
		Vector2(740.0, floor_y),
	])

	_near_mountains = PackedVector2Array([
		Vector2(-740.0, floor_y),
		Vector2(-740.0, 430.0),
		Vector2(-630.0, 392.0),
		Vector2(-520.0, 428.0),
		Vector2(-410.0, 378.0),
		Vector2(-295.0, 436.0),
		Vector2(-190.0, 412.0),
		Vector2(-95.0, 452.0),
		Vector2(95.0, 452.0),
		Vector2(195.0, 410.0),
		Vector2(305.0, 438.0),
		Vector2(415.0, 380.0),
		Vector2(525.0, 426.0),
		Vector2(635.0, 390.0),
		Vector2(740.0, 432.0),
		Vector2(740.0, floor_y),
	])


func _draw() -> void:
	var half_w := GameConstants.ARENA_WALL_HALF
	var floor_y := GameConstants.ARENA_FLOOR_Y

	_draw_sky_and_celestial(floor_y)
	_draw_mountains_and_mist(floor_y)
	_draw_grand_mirror(floor_y)
	_draw_floating_shards()
	_draw_floor_and_reflections(half_w, floor_y)
	_draw_shrine_walls(half_w, floor_y)
	_draw_ambient_motes(floor_y)


func _draw_sky_and_celestial(floor_y: float) -> void:
	var sky_top := Color(0.03, 0.04, 0.10, 1.0)
	var sky_mid := Color(0.07, 0.11, 0.24, 1.0) if not mirror_realm_active else Color(0.11, 0.08, 0.26, 1.0)
	var sky_hor := Color(0.13, 0.20, 0.36, 1.0) if not mirror_realm_active else Color(0.17, 0.16, 0.38, 1.0)

	# Bầu trời chuyển sắc 2 dải mượt
	draw_polygon(
		PackedVector2Array([
			Vector2(-740.0, -80.0), Vector2(740.0, -80.0),
			Vector2(740.0, 250.0), Vector2(-740.0, 250.0),
		]),
		PackedColorArray([sky_top, sky_top, sky_mid, sky_mid])
	)
	draw_polygon(
		PackedVector2Array([
			Vector2(-740.0, 250.0), Vector2(740.0, 250.0),
			Vector2(740.0, floor_y), Vector2(-740.0, floor_y),
		]),
		PackedColorArray([sky_mid, sky_mid, sky_hor, sky_hor])
	)

	# Sao lấp lánh
	for s in _stars:
		var tw := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * float(s["speed"]) + float(s["phase"])))
		draw_circle(s["pos"], float(s["r"]), Color(0.82, 0.92, 1.0, tw * 0.78))

	# Vầng Trăng Nhật Thực / Vòng Ấn Ký Thiên Tinh phía sau Đại Gương
	var moon_c := Vector2(0.0, 168.0)
	var halo_col := Color(0.32, 0.76, 1.0, 1.0) if not mirror_realm_active else Color(0.68, 0.48, 1.0, 1.0)
	for i in 4:
		var r := 82.0 + float(i) * 26.0
		draw_circle(moon_c, r, Color(halo_col.r, halo_col.g, halo_col.b, 0.045 - float(i) * 0.008))

	# Vòng la bàn cổ ngữ xoay chậm
	var ring_r := 112.0
	draw_arc(moon_c, ring_r, 0.0, TAU, 64, Color(halo_col.r, halo_col.g, halo_col.b, 0.22), 1.4)
	draw_arc(moon_c, ring_r + 12.0, 0.0, TAU, 64, Color(halo_col.r, halo_col.g, halo_col.b, 0.11), 1.0)
	for i in 12:
		var ang := _time * 0.08 + float(i) * TAU / 12.0
		var p0 := moon_c + Vector2(cos(ang), sin(ang)) * (ring_r - 5.0)
		var p1 := moon_c + Vector2(cos(ang), sin(ang)) * (ring_r + 6.0)
		draw_line(p0, p1, Color(halo_col.r, halo_col.g, halo_col.b, 0.30), 1.5)

	# Đĩa trăng khuyết ánh gương
	draw_circle(moon_c, 58.0, Color(0.86, 0.94, 1.0, 0.22))
	draw_circle(moon_c + Vector2(12.0, -8.0), 50.0, sky_mid.lerp(sky_top, 0.35))
	draw_arc(moon_c, 58.0, -PI * 0.85, PI * 0.85, 48, Color(0.82, 0.95, 1.0, 0.48), 2.0)


func _draw_mountains_and_mist(floor_y: float) -> void:
	draw_colored_polygon(_far_mountains, Color(0.06, 0.09, 0.19, 0.92))
	# Lớp sương mù giữa hai tầng núi
	draw_polygon(
		PackedVector2Array([
			Vector2(-740.0, 355.0), Vector2(740.0, 355.0),
			Vector2(740.0, floor_y), Vector2(-740.0, floor_y),
		]),
		PackedColorArray([
			Color(0.22, 0.36, 0.58, 0.0),
			Color(0.22, 0.36, 0.58, 0.0),
			Color(0.24, 0.44, 0.68, 0.16),
			Color(0.24, 0.44, 0.68, 0.16),
		])
	)
	draw_colored_polygon(_near_mountains, Color(0.05, 0.07, 0.14, 0.96))

	# Hàng cột tàn tích xa xa hai bên sườn đền
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var px: float = side * (225.0 + float(k) * 88.0)
			var ph := 92.0 - float(k) * 14.0
			draw_rect(Rect2(px - 7.0, floor_y - ph, 14.0, ph), Color(0.08, 0.11, 0.20, 0.85))
			draw_rect(Rect2(px - 11.0, floor_y - ph - 5.0, 22.0, 5.0), Color(0.11, 0.15, 0.27, 0.85))


func _draw_grand_mirror(floor_y: float) -> void:
	# Khung Đại Gương Cổ ở trung tâm hậu cảnh (x: -88..88, y: 196..floor_y)
	var mw := 78.0
	var top_y := 208.0
	var frame_col := Color(0.13, 0.17, 0.28, 1.0)
	var trim_col := Color(0.28, 0.42, 0.62, 0.85)
	var rune_col := Color(0.32, 0.85, 1.0, 0.78) if not mirror_realm_active else Color(0.75, 0.52, 1.0, 0.92)

	# Bậc thềm đá dưới chân Đại Gương
	draw_rect(Rect2(-mw - 26.0, floor_y - 16.0, (mw + 26.0) * 2.0, 16.0), Color(0.10, 0.13, 0.22, 1.0))
	draw_rect(Rect2(-mw - 16.0, floor_y - 28.0, (mw + 16.0) * 2.0, 12.0), Color(0.12, 0.16, 0.26, 1.0))

	# Khung đá vòm nhọn
	var outer_arch := PackedVector2Array([
		Vector2(-mw - 14.0, floor_y - 28.0),
		Vector2(-mw - 14.0, top_y + 30.0),
		Vector2(-mw * 0.55, top_y - 12.0),
		Vector2(0.0, top_y - 32.0),
		Vector2(mw * 0.55, top_y - 12.0),
		Vector2(mw + 14.0, top_y + 30.0),
		Vector2(mw + 14.0, floor_y - 28.0),
	])
	draw_colored_polygon(outer_arch, frame_col)
	var arch_outline := outer_arch.duplicate()
	arch_outline.append(outer_arch[0])
	draw_polyline(arch_outline, trim_col, 2.0, true)

	# Mặt kính Đại Gương bên trong
	var glass_poly := PackedVector2Array([
		Vector2(-mw + 4.0, floor_y - 30.0),
		Vector2(-mw + 4.0, top_y + 34.0),
		Vector2(-mw * 0.45, top_y + 2.0),
		Vector2(0.0, top_y - 14.0),
		Vector2(mw * 0.45, top_y + 2.0),
		Vector2(mw - 4.0, top_y + 34.0),
		Vector2(mw - 4.0, floor_y - 30.0),
	])
	var g_top := Color(0.08, 0.18, 0.34, 0.92) if not mirror_realm_active else Color(0.18, 0.12, 0.42, 0.95)
	var g_bot := Color(0.18, 0.44, 0.66, 0.88) if not mirror_realm_active else Color(0.32, 0.68, 0.92, 0.92)
	var g_cols := PackedColorArray([g_bot, g_top, g_top, g_top, g_top, g_top, g_bot])
	draw_polygon(glass_poly, g_cols)

	# Ánh lấp lánh chéo trên mặt Đại Gương
	var pulse := 0.65 + 0.35 * sin(_time * 2.4)
	draw_line(Vector2(-48.0, top_y + 48.0), Vector2(36.0, floor_y - 54.0), Color(0.78, 0.95, 1.0, 0.14 * pulse), 14.0)
	draw_line(Vector2(-24.0, top_y + 32.0), Vector2(54.0, floor_y - 86.0), Color(0.88, 0.98, 1.0, 0.10 * pulse), 6.0)

	# Vòng năng lượng trung tâm Đại Gương khi chế độ Gương Đấu kích hoạt
	var mirror_center := Vector2(0.0, (top_y + floor_y) * 0.5 + 8.0)
	var portal_alpha := 0.58 if mirror_realm_active else 0.22
	draw_arc(mirror_center, 38.0 + sin(_time * 3.0) * 2.5, 0.0, TAU, 40, Color(rune_col.r, rune_col.g, rune_col.b, portal_alpha * pulse), 2.0)
	draw_arc(mirror_center, 22.0, _time * 0.8, _time * 0.8 + PI * 1.4, 24, Color(0.9, 0.97, 1.0, portal_alpha), 1.6)

	# Ấn ký cổ ngữ phát sáng dọc hai trụ Đại Gương
	for side: float in [-1.0, 1.0]:
		var rx: float = side * (mw + 4.0)
		for idx in 5:
			var ry := top_y + 52.0 + float(idx) * 46.0
			var glow_a := (0.45 + 0.45 * sin(_time * 3.2 + float(idx) * 0.9))
			draw_rect(Rect2(rx - 2.5, ry, 5.0, 14.0), Color(rune_col.r, rune_col.g, rune_col.b, glow_a))


func _draw_floating_shards() -> void:
	for s in _shards:
		var base: Vector2 = s["base"]
		var phase: float = s["phase"]
		var bob := sin(_time * 1.6 + phase) * 9.0
		var c := base + Vector2(0.0, bob)
		var w: float = s["w"]
		var h: float = s["h"]
		var tilt: float = float(s["tilt"]) + sin(_time * 0.9 + phase) * 0.08
		var ux := Vector2(cos(tilt), sin(tilt))
		var uy := Vector2(-sin(tilt), cos(tilt))
		var poly := PackedVector2Array([
			c - uy * h * 0.55,
			c + ux * w * 0.5 - uy * h * 0.08,
			c + uy * h * 0.48,
			c - ux * w * 0.5 + uy * h * 0.08,
		])
		draw_colored_polygon(poly, Color(0.25, 0.55, 0.82, 0.34))
		# Nửa mặt bắt sáng
		draw_colored_polygon(
			PackedVector2Array([poly[0], poly[1], poly[2]]),
			Color(0.68, 0.92, 1.0, 0.28)
		)
		var outline := poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, Color(0.75, 0.94, 1.0, 0.55), 1.2, true)


func _draw_floor_and_reflections(half_w: float, floor_y: float) -> void:
	var floor_left := -half_w - WALL_THICKNESS - 140.0
	var floor_right := half_w + WALL_THICKNESS + 140.0
	var bottom_y := floor_y + 230.0

	# 1. Nền đá cẩm thạch đen bóng (Obsidian Mirror Slab)
	var f_top := Color(0.09, 0.13, 0.23, 1.0) if not mirror_realm_active else Color(0.11, 0.11, 0.26, 1.0)
	var f_bot := Color(0.03, 0.04, 0.09, 1.0)
	draw_polygon(
		PackedVector2Array([
			Vector2(floor_left, floor_y), Vector2(floor_right, floor_y),
			Vector2(floor_right, bottom_y), Vector2(floor_left, bottom_y),
		]),
		PackedColorArray([f_top, f_top, f_bot, f_bot])
	)

	# Phản chiếu mờ của Đại Gương & vầng trăng dưới mặt sàn trung tâm
	draw_polygon(
		PackedVector2Array([
			Vector2(-95.0, floor_y), Vector2(95.0, floor_y),
			Vector2(145.0, bottom_y), Vector2(-145.0, bottom_y),
		]),
		PackedColorArray([
			Color(0.24, 0.58, 0.86, 0.18),
			Color(0.24, 0.58, 0.86, 0.18),
			Color(0.08, 0.18, 0.35, 0.0),
			Color(0.08, 0.18, 0.35, 0.0),
		])
	)

	# 2. Phản chiếu trực tiếp hình dáng thật lộn ngược của 2 đấu sĩ xuống mặt sàn gương!
	for f in fighters:
		if f == null or not is_instance_valid(f):
			continue
		var air_gap := maxf(0.0, floor_y - f.position.y)
		var refl_alpha := clampf(0.30 - air_gap / 650.0, 0.06, 0.30)
		var refl_origin := Vector2(f.position.x, floor_y + air_gap * 0.72 + 1.5)
		draw_set_transform(refl_origin, 0.0, Vector2(1.0, -0.74))
		FighterRenderer.draw_fighter(self, f, f.anim_time, refl_alpha, Color(0, 0, 0, 0), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 3. Lớp phủ kính mờ + lưới gạch phối cảnh trên mặt sàn
	var line_col := Color(0.38, 0.68, 0.95, 0.13)
	for i in range(-8, 9):
		var x_top := float(i) * 64.0
		var x_bot := x_top * 1.42
		var c := Color(0.48, 0.85, 1.0, 0.28) if i == 0 else line_col
		draw_line(Vector2(x_top, floor_y), Vector2(x_bot, bottom_y), c, 2.0 if i == 0 else 1.1)

	var row_offsets := [16.0, 38.0, 68.0, 108.0, 160.0]
	for off in row_offsets:
		var y := floor_y + float(off)
		var fade := clampf(1.0 - float(off) / 185.0, 0.15, 1.0)
		draw_line(
			Vector2(floor_left, y),
			Vector2(floor_right, y),
			Color(0.35, 0.62, 0.90, 0.12 * fade),
			1.1
		)

	# Đường viền mặt sàn rực sáng nơi chân nhân vật tiếp đất (y = floor_y)
	draw_line(
		Vector2(-half_w, floor_y),
		Vector2(half_w, floor_y),
		Color(0.45, 0.82, 1.0, 0.62),
		2.6
	)
	draw_line(
		Vector2(-half_w, floor_y + 2.5),
		Vector2(half_w, floor_y + 2.5),
		Color(0.15, 0.32, 0.55, 0.45),
		3.0
	)
	# Ấn ký vạch giao đấu trung tâm sân (x = 0)
	draw_circle(Vector2(0.0, floor_y), 4.5, Color(0.65, 0.92, 1.0, 0.75))


func _draw_shrine_walls(half_w: float, floor_y: float) -> void:
	# Trụ đá cổ ngữ hai đầu đấu trường (±half_w) + kết giới ánh sáng cảnh báo ép góc
	var pillar_h := 350.0
	var top_y := floor_y - pillar_h
	var rune_col := Color(0.28, 0.84, 1.0, 1.0) if not mirror_realm_active else Color(0.76, 0.52, 1.0, 1.0)

	for side: float in [-1.0, 1.0]:
		var inner_x: float = side * half_w
		var rect_x: float = inner_x if side > 0.0 else (inner_x - WALL_THICKNESS)

		# Thân trụ đá bậc thang
		draw_rect(Rect2(rect_x, top_y, WALL_THICKNESS, pillar_h + 26.0), Color(0.10, 0.13, 0.22, 1.0))
		draw_rect(Rect2(rect_x + 4.0, top_y + 8.0, WALL_THICKNESS - 8.0, pillar_h + 10.0), Color(0.14, 0.18, 0.30, 1.0))
		draw_rect(Rect2(rect_x - 5.0, top_y - 10.0, WALL_THICKNESS + 10.0, 12.0), Color(0.18, 0.24, 0.38, 1.0))
		draw_rect(Rect2(rect_x - 6.0, floor_y - 20.0, WALL_THICKNESS + 12.0, 24.0), Color(0.16, 0.21, 0.34, 1.0))

		# Đài lửa linh hồn trên đỉnh trụ đá
		var flame_c := Vector2(rect_x + WALL_THICKNESS * 0.5, top_y - 20.0)
		var flicker := sin(_time * 9.0 + side) * 2.2
		draw_circle(flame_c, 15.0, Color(rune_col.r, rune_col.g, rune_col.b, 0.20))
		draw_colored_polygon(PackedVector2Array([
			flame_c + Vector2(-7.0, 8.0),
			flame_c + Vector2(0.0, -14.0 + flicker),
			flame_c + Vector2(7.0, 8.0),
		]), Color(rune_col.r, rune_col.g, rune_col.b, 0.85))
		draw_colored_polygon(PackedVector2Array([
			flame_c + Vector2(-3.5, 7.0),
			flame_c + Vector2(0.0, -7.0 + flicker * 0.6),
			flame_c + Vector2(3.5, 7.0),
		]), Color(0.95, 0.98, 1.0, 0.92))

		# Rãnh ấn ký phát sáng dọc thân trụ
		var cx: float = rect_x + WALL_THICKNESS * 0.5
		for k in 6:
			var ry := top_y + 30.0 + float(k) * 50.0
			var pa := 0.4 + 0.45 * sin(_time * 2.8 + float(k) * 0.8 + side)
			draw_rect(Rect2(cx - 3.0, ry, 6.0, 22.0), Color(rune_col.r, rune_col.g, rune_col.b, pa))

		# Kiểm tra xem có đấu sĩ nào bị ép sát tường bên này không để tăng sáng kết giới
		var proximity := 0.0
		for f in fighters:
			if f != null and is_instance_valid(f):
				var dist_wall := absf(f.position.x - inner_x)
				if dist_wall < 90.0:
					proximity = maxf(proximity, 1.0 - dist_wall / 90.0)

		var ward_a := 0.14 + proximity * 0.52
		draw_line(
			Vector2(inner_x, top_y),
			Vector2(inner_x, floor_y),
			Color(rune_col.r, rune_col.g, rune_col.b, ward_a),
			2.2 + proximity * 2.5
		)


func _draw_ambient_motes(floor_y: float) -> void:
	var span := floor_y - 70.0
	for m in _motes:
		var raw_y := float(m["y"]) - _time * float(m["vy"])
		var wrapped_y := 70.0 + fposmod(raw_y - 70.0, span)
		var wx := float(m["x"]) + sin(_time * 1.4 + float(m["phase"])) * float(m["amp"])
		var fade := sin(clampf((wrapped_y - 70.0) / span, 0.0, 1.0) * PI)
		var col := Color(1.0, 0.86, 0.52, 0.48 * fade) if bool(m["warm"]) else Color(0.52, 0.90, 1.0, 0.46 * fade)
		draw_circle(Vector2(wx, wrapped_y), float(m["r"]), col)
