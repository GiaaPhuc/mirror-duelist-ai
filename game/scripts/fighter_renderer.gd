class_name FighterRenderer
extends RefCounted
## Bộ vẽ võ sĩ phong cách Stylized Shadow-Neon khớp hoàn toàn với hurtbox 28x56
## và tầm đánh / frame data của SPEC.md (light / heavy / kick / block / dodge / dash / stun / KO).


static func compute_pose(f: FighterCharacter, anim_time: float) -> Dictionary:
	var dir := float(f.facing)
	var grounded := f.is_on_floor()

	# Gốc khớp mặc định (theo hướng nhìn sang phải, sau đó nhân ngang với `dir`)
	var hip := Vector2(0.0, -25.0)
	var shoulder := Vector2(1.0, -42.0)
	var head := Vector2(2.0, -51.5)

	var foot_f := Vector2(8.0, 0.0)
	var foot_b := Vector2(-8.0, 0.0)
	var hand_f := Vector2(12.0, -35.0)
	var hand_b := Vector2(-6.0, -33.0)

	var slash_kind := "" # "light" | "heavy" | "kick" | "charge"
	var slash_progress := 0.0

	if f.hp <= 0.0:
		# Tư thế gục ngã K.O. trên mặt sàn gương
		hip = Vector2(-6.0, -7.0)
		shoulder = Vector2(-20.0, -9.0)
		head = Vector2(-29.0, -8.5)
		foot_f = Vector2(14.0, -2.0)
		foot_b = Vector2(6.0, -1.0)
		hand_f = Vector2(-12.0, -2.0)
		hand_b = Vector2(-25.0, -3.0)
	elif f.state == FighterCharacter.State.STUN:
		# Bị choáng / giật ngửa về sau
		var recoil := clampf(float(f.stun_left) / 16.0, 0.25, 1.0)
		hip = Vector2(-3.0 * recoil, -24.0)
		shoulder = Vector2(-8.0 * recoil, -40.5)
		head = Vector2(-11.5 * recoil, -49.5)
		foot_f = Vector2(7.0, 0.0 if grounded else -4.0)
		foot_b = Vector2(-10.0, 0.0 if grounded else -6.0)
		hand_f = Vector2(4.0, -45.0)
		hand_b = Vector2(-13.0, -38.0)
	elif f.state == FighterCharacter.State.BLOCK:
		# Thế thủ kiên cố hai tay bắt chéo trước ngực + khiên năng lượng
		var breathe := sin(anim_time * 6.0) * 0.8
		hip = Vector2(-2.0, -23.5 + breathe * 0.5)
		shoulder = Vector2(0.0, -39.5 + breathe)
		head = Vector2(1.5, -48.5 + breathe)
		foot_f = Vector2(10.0, 0.0)
		foot_b = Vector2(-10.5, 0.0)
		hand_f = Vector2(12.5, -39.0 + breathe)
		hand_b = Vector2(9.5, -33.0 + breathe)
	elif f.state == FighterCharacter.State.DASH:
		# Lao vút về phía trước khí động học
		hip = Vector2(4.0, -22.0)
		shoulder = Vector2(13.0, -36.5)
		head = Vector2(18.0, -44.0)
		foot_f = Vector2(12.0, -3.0)
		foot_b = Vector2(-16.0, -5.0)
		hand_f = Vector2(16.0, -32.0)
		hand_b = Vector2(-12.0, -39.0)
	elif f.state == FighterCharacter.State.DODGE:
		# Lướt lùi bóng ma né đòn
		hip = Vector2(-3.0, -21.5)
		shoulder = Vector2(-10.0, -36.0)
		head = Vector2(-7.0, -45.0)
		foot_f = Vector2(11.0, -1.0)
		foot_b = Vector2(-14.0, -2.0)
		hand_f = Vector2(8.0, -34.0)
		hand_b = Vector2(-15.0, -31.0)
	elif f.state == FighterCharacter.State.ATTACK:
		var t := f.state_ticks
		var act := f.current_action
		if act == GameConstants.ACTION_LIGHT:
			# Startup 4, Active 3 (5..7), Recovery 8 (8..15)
			if t <= 4:
				var u := float(t) / 4.0
				hip = Vector2(lerpf(0.0, -2.0, u), -24.5)
				shoulder = Vector2(lerpf(1.0, -3.0, u), -41.5)
				head = Vector2(1.0, -50.5)
				hand_f = Vector2(lerpf(12.0, -4.0, u), -36.0)
				hand_b = Vector2(6.0, -34.0)
				foot_f = Vector2(9.0, 0.0)
				foot_b = Vector2(-9.0, 0.0)
			elif t <= 7:
				var u := float(t - 4) / 3.0
				hip = Vector2(5.0, -24.0)
				shoulder = Vector2(10.0, -40.5)
				head = Vector2(11.0, -49.5)
				hand_f = Vector2(46.0, -34.0)
				hand_b = Vector2(-5.0, -35.0)
				foot_f = Vector2(13.0, 0.0)
				foot_b = Vector2(-11.0, 0.0)
				slash_kind = "light"
				slash_progress = u
			else:
				var u := clampf(float(t - 7) / 8.0, 0.0, 1.0)
				hip = Vector2(lerpf(5.0, 0.0, u), -24.5)
				shoulder = Vector2(lerpf(10.0, 1.0, u), -41.5)
				head = Vector2(lerpf(11.0, 2.0, u), -50.5)
				hand_f = Vector2(lerpf(42.0, 12.0, u), -34.5)
				hand_b = Vector2(-6.0, -33.0)
				foot_f = Vector2(lerpf(13.0, 8.0, u), 0.0)
				foot_b = Vector2(lerpf(-11.0, -8.0, u), 0.0)
		elif act == GameConstants.ACTION_HEAVY:
			# Startup 12, Active 4 (13..16), Recovery 20 (17..36)
			if t <= 12:
				var u := float(t) / 12.0
				hip = Vector2(lerpf(0.0, -5.0, u), lerpf(-25.0, -21.5, u))
				shoulder = Vector2(lerpf(1.0, -8.0, u), lerpf(-42.0, -38.0, u))
				head = Vector2(lerpf(2.0, -5.0, u), lerpf(-51.5, -47.0, u))
				hand_f = Vector2(lerpf(12.0, -14.0, u), lerpf(-35.0, -33.0, u))
				hand_b = Vector2(lerpf(-6.0, 8.0, u), -37.0)
				foot_f = Vector2(7.0, 0.0)
				foot_b = Vector2(-13.0, 0.0)
				slash_kind = "charge"
				slash_progress = u
			elif t <= 16:
				var u := float(t - 12) / 4.0
				hip = Vector2(8.0, -23.0)
				shoulder = Vector2(15.0, -39.0)
				head = Vector2(16.0, -48.0)
				hand_f = Vector2(54.0, -33.0)
				hand_b = Vector2(-9.0, -36.0)
				foot_f = Vector2(16.0, 0.0)
				foot_b = Vector2(-13.0, 0.0)
				slash_kind = "heavy"
				slash_progress = u
			else:
				var u := clampf(float(t - 16) / 20.0, 0.0, 1.0)
				hip = Vector2(lerpf(8.0, 0.0, u), lerpf(-23.0, -25.0, u))
				shoulder = Vector2(lerpf(15.0, 1.0, u), lerpf(-39.0, -42.0, u))
				head = Vector2(lerpf(16.0, 2.0, u), lerpf(-48.0, -51.5, u))
				hand_f = Vector2(lerpf(50.0, 12.0, u), -34.0)
				hand_b = Vector2(lerpf(-9.0, -6.0, u), -33.0)
				foot_f = Vector2(lerpf(16.0, 8.0, u), 0.0)
				foot_b = Vector2(lerpf(-13.0, -8.0, u), 0.0)
		elif act == GameConstants.ACTION_KICK:
			# Startup 8, Active 4 (9..12), Recovery 14 (13..26)
			if t <= 8:
				var u := float(t) / 8.0
				hip = Vector2(lerpf(0.0, -2.0, u), -25.0)
				shoulder = Vector2(lerpf(1.0, -6.0, u), -42.0)
				head = Vector2(lerpf(2.0, -5.0, u), -51.0)
				foot_b = Vector2(-6.0, 0.0)
				foot_f = Vector2(lerpf(8.0, 10.0, u), lerpf(0.0, -20.0, u))
				hand_f = Vector2(9.0, -37.0)
				hand_b = Vector2(-10.0, -35.0)
			elif t <= 12:
				var u := float(t - 8) / 4.0
				hip = Vector2(3.0, -24.0)
				shoulder = Vector2(-7.0, -40.5)
				head = Vector2(-6.0, -49.5)
				foot_b = Vector2(-7.0, 0.0)
				foot_f = Vector2(72.0, -16.0)
				hand_f = Vector2(10.0, -36.0)
				hand_b = Vector2(-13.0, -38.0)
				slash_kind = "kick"
				slash_progress = u
			else:
				var u := clampf(float(t - 12) / 14.0, 0.0, 1.0)
				hip = Vector2(lerpf(3.0, 0.0, u), -25.0)
				shoulder = Vector2(lerpf(-7.0, 1.0, u), -42.0)
				head = Vector2(lerpf(-6.0, 2.0, u), -51.5)
				foot_b = Vector2(-8.0, 0.0)
				foot_f = Vector2(lerpf(62.0, 8.0, u), lerpf(-15.0, 0.0, u))
				hand_f = Vector2(12.0, -35.0)
				hand_b = Vector2(-6.0, -33.0)
	elif not grounded:
		# Tư thế nhảy / rơi trên không
		var rising := f.velocity.y < -20.0
		hip = Vector2(0.0, -26.0)
		shoulder = Vector2(3.0 if rising else 1.0, -43.0)
		head = Vector2(4.0 if rising else 2.0, -52.5)
		foot_f = Vector2(9.0, -10.0 if rising else -4.0)
		foot_b = Vector2(-8.0, -5.0 if rising else -9.0)
		hand_f = Vector2(13.0, -39.0 if rising else -34.0)
		hand_b = Vector2(-9.0, -37.0 if rising else -41.0)
	elif absf(f.velocity.x) > 10.0:
		# Di chuyển tới / lùi
		var moving_fwd := (f.velocity.x * dir) > 0.0
		var freq := 13.0 if moving_fwd else 10.5
		var phase := anim_time * freq
		var swing := sin(phase)
		var lift_f := maxf(0.0, cos(phase)) * -5.5
		var lift_b := maxf(0.0, -cos(phase)) * -5.5
		var lean := 4.5 if moving_fwd else -2.5
		var bob := absf(sin(phase)) * -2.2
		hip = Vector2(lean * 0.35, -24.5 + bob)
		shoulder = Vector2(lean, -41.5 + bob)
		head = Vector2(lean + 1.5, -51.0 + bob)
		foot_f = Vector2(swing * 11.5 + 1.5, lift_f)
		foot_b = Vector2(-swing * 11.5 - 1.5, lift_b)
		hand_f = Vector2(12.0 - swing * 4.5, -35.5 + bob)
		hand_b = Vector2(-5.0 + swing * 4.5, -33.0 + bob)
	else:
		# Thế đứng thủ võ thuật thở nhịp nhàng
		var breathe := sin(anim_time * 4.2)
		hip = Vector2(0.0, -24.8 + breathe * 0.7)
		shoulder = Vector2(1.5, -41.8 + breathe * 1.3)
		head = Vector2(2.5, -51.3 + breathe * 1.5)
		foot_f = Vector2(8.5, 0.0)
		foot_b = Vector2(-8.5, 0.0)
		hand_f = Vector2(13.0, -36.5 + breathe * 1.4)
		hand_b = Vector2(-4.5, -33.0 + breathe * 1.0)

	return {
		"dir": dir,
		"hip": Vector2(hip.x * dir, hip.y),
		"shoulder": Vector2(shoulder.x * dir, shoulder.y),
		"head": Vector2(head.x * dir, head.y),
		"foot_f": Vector2(foot_f.x * dir, foot_f.y),
		"foot_b": Vector2(foot_b.x * dir, foot_b.y),
		"hand_f": Vector2(hand_f.x * dir, hand_f.y),
		"hand_b": Vector2(hand_b.x * dir, hand_b.y),
		"slash_kind": slash_kind,
		"slash_progress": slash_progress,
	}


static func _solve_joint(a: Vector2, b: Vector2, len1: float, len2: float, bend_sign: float) -> Vector2:
	var diff := b - a
	var d := diff.length()
	if d < 0.001:
		return a + Vector2(0.0, len1)
	var max_len := (len1 + len2) * 0.995
	if d >= max_len:
		return a + diff.normalized() * len1
	var min_len := absf(len1 - len2) + 0.01
	var dc := maxf(d, min_len)
	var cos_a := clampf((len1 * len1 + dc * dc - len2 * len2) / (2.0 * len1 * dc), -1.0, 1.0)
	var angle := acos(cos_a)
	var base_dir := diff / d
	var perp := Vector2(-base_dir.y, base_dir.x) * bend_sign
	return a + base_dir * (cos(angle) * len1) + perp * (sin(angle) * len1)


static func _draw_capsule(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	canvas.draw_line(a, b, col, width, true)
	canvas.draw_circle(a, width * 0.5, col)
	canvas.draw_circle(b, width * 0.5, col)


static func draw_fighter(
	canvas: CanvasItem,
	f: FighterCharacter,
	anim_time: float,
	alpha_mult: float = 1.0,
	silhouette_override: Color = Color(0, 0, 0, 0),
	is_reflection: bool = false
) -> void:
	var pose := compute_pose(f, anim_time)
	var dir: float = pose["dir"]
	var hip: Vector2 = pose["hip"]
	var shoulder: Vector2 = pose["shoulder"]
	var head: Vector2 = pose["head"]
	var foot_f: Vector2 = pose["foot_f"]
	var foot_b: Vector2 = pose["foot_b"]
	var hand_f: Vector2 = pose["hand_f"]
	var hand_b: Vector2 = pose["hand_b"]

	var invuln_alpha := 0.42 if f.is_invincible() else (0.78 if f.state == FighterCharacter.State.DODGE else 1.0)
	var a := alpha_mult * invuln_alpha
	var use_override := silhouette_override.a > 0.001

	var primary := f.body_color
	var accent := f.accent_color
	var suit_dark := Color(0.08, 0.10, 0.16, a)
	var suit_mid := primary.darkened(0.48)
	suit_mid.a = a
	var suit_back := Color(0.05, 0.06, 0.11, a)
	var wrap_col := accent
	wrap_col.a = a
	var skin_col := Color(0.92, 0.84, 0.78, a)

	if f.is_mirror_clone:
		suit_dark = Color(0.07, 0.05, 0.15, a * 0.94)
		suit_mid = Color(0.16, 0.14, 0.30, a * 0.94)
		suit_back = Color(0.04, 0.03, 0.10, a * 0.92)
		skin_col = Color(0.78, 0.88, 0.98, a)

	if f.hit_flash_ticks > 0 and not is_reflection and not use_override:
		suit_dark = suit_dark.lerp(Color(1.0, 0.96, 0.82, a), 0.72)
		suit_mid = suit_mid.lerp(Color(1.0, 0.96, 0.82, a), 0.72)
		wrap_col = Color(1.0, 1.0, 1.0, a)
	elif f.state == FighterCharacter.State.STUN and not use_override:
		suit_mid = suit_mid.lerp(Color(1.0, 0.75, 0.25, a), 0.35)

	if use_override:
		var ov := silhouette_override
		ov.a *= a
		suit_dark = ov
		suit_mid = ov
		suit_back = ov
		wrap_col = ov
		skin_col = ov

	# Bóng đổ tiếp đất dưới chân (chỉ vẽ cho nhân vật thật)
	if not is_reflection and not use_override:
		var height_factor := clampf(1.0 - (GameConstants.ARENA_FLOOR_Y - f.position.y) / 260.0, 0.25, 1.0)
		var sh_y := GameConstants.ARENA_FLOOR_Y - f.position.y
		var sh_rx := 18.0 * height_factor
		var sh_pts := PackedVector2Array()
		for i in 16:
			var ang := TAU * float(i) / 16.0
			sh_pts.append(Vector2(cos(ang) * sh_rx, sh_y + sin(ang) * 4.2 * height_factor))
		canvas.draw_colored_polygon(sh_pts, Color(0.0, 0.0, 0.04, 0.42 * height_factor * a))

		# Vòng hào quang mặt đất cho Bản Sao Gương
		if f.is_mirror_clone:
			var pulse := 0.7 + 0.3 * sin(anim_time * 5.0)
			canvas.draw_arc(
				Vector2(0.0, sh_y),
				19.0,
				0.0,
				TAU,
				24,
				Color(accent.r, accent.g, accent.b, 0.35 * pulse * a),
				1.8
			)

	# Hào quang mảnh gương lơ lửng sau lưng cho AI Mirror
	if f.is_mirror_clone and not use_override and not is_reflection:
		for i in 3:
			var ang := anim_time * 2.2 + float(i) * TAU / 3.0
			var shard_c := shoulder + Vector2(cos(ang) * 16.0 - dir * 5.0, sin(ang * 1.3) * 9.0 - 2.0)
			var pts := PackedVector2Array([
				shard_c + Vector2(0.0, -5.0),
				shard_c + Vector2(3.2, 0.0),
				shard_c + Vector2(0.0, 5.0),
				shard_c + Vector2(-3.2, 0.0),
			])
			canvas.draw_colored_polygon(pts, Color(0.65, 0.88, 1.0, 0.48 * a))
			canvas.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.75 * a), 1.0)

	# Khớp gối (gối gập về hướng nhìn: `bend_sign = -dir` khi đi từ hip xuống foot)
	var knee_b := _solve_joint(hip, foot_b, 13.5, 13.5, -dir)
	var knee_f := _solve_joint(hip, foot_f, 13.5, 13.5, -dir)
	# Khớp khuỷu tay (khuỷu gập xuống/lùi: `bend_sign = dir`)
	var elbow_b := _solve_joint(shoulder, hand_b, 10.5, 10.5, dir)
	var elbow_f := _solve_joint(shoulder, hand_f, 10.5, 10.5, dir)

	# 1. Dải băng trán bay theo quán tính (vẽ lớp sau)
	if not use_override and f.scarf_points.size() >= 2 and not is_reflection:
		for i in range(f.scarf_points.size() - 1):
			var p0: Vector2 = f.scarf_points[i] - f.position
			var p1: Vector2 = f.scarf_points[i + 1] - f.position
			var t_w := lerpf(4.2, 1.2, float(i) / float(f.scarf_points.size() - 1))
			var sc := wrap_col
			sc.a = a * lerpf(0.95, 0.35, float(i) / float(f.scarf_points.size() - 1))
			canvas.draw_line(p0, p1, sc, t_w, true)
	elif not use_override:
		# Dải băng đơn giản khi vẽ phản chiếu
		var tail_end := head + Vector2(-dir * 16.0, 4.0 + sin(anim_time * 7.0) * 2.5)
		canvas.draw_line(head + Vector2(-dir * 4.0, -1.0), tail_end, wrap_col, 3.0, true)

	# 2. Tay sau & Chân sau
	_draw_capsule(canvas, shoulder, elbow_b, 5.2, suit_back)
	_draw_capsule(canvas, elbow_b, hand_b, 4.4, wrap_col.darkened(0.35))
	_draw_capsule(canvas, hip + Vector2(-dir * 2.0, 0.0), knee_b, 6.6, suit_back)
	_draw_capsule(canvas, knee_b, foot_b, 5.2, suit_back)
	canvas.draw_line(foot_b, foot_b + Vector2(dir * 5.0, 0.0), wrap_col.darkened(0.3), 3.6, true)

	# 3. Thân võ phục (Torso hình thang cơ bắp + đai lưng)
	var torso_axis := (shoulder - hip).normalized()
	var torso_perp := Vector2(-torso_axis.y, torso_axis.x)
	var sh_half := 7.8
	var hip_half := 5.4
	var torso_poly := PackedVector2Array([
		shoulder - torso_perp * sh_half,
		shoulder + torso_perp * sh_half,
		hip + torso_perp * hip_half,
		hip - torso_perp * hip_half,
	])
	canvas.draw_colored_polygon(torso_poly, suit_dark)
	# Mảng giáp ngực / vạt áo sáng màu chủ đạo
	var chest_poly := PackedVector2Array([
		shoulder - torso_perp * (sh_half * 0.35),
		shoulder + torso_perp * (sh_half * 0.92),
		hip + torso_perp * (hip_half * 0.72),
		hip - torso_perp * (hip_half * 0.15),
	])
	canvas.draw_colored_polygon(chest_poly, suit_mid)
	if not use_override:
		# Cổ áo chữ V & đai lưng võ sĩ
		canvas.draw_line(shoulder + Vector2(dir * 2.0, 1.0), hip + Vector2(dir * 1.5, -5.0), wrap_col, 1.8, true)
		canvas.draw_line(hip - torso_perp * (hip_half + 0.8), hip + torso_perp * (hip_half + 0.8), wrap_col, 3.4, true)

	# 4. Chân trước (đùi + ống quyển quấn băng phát sáng + bàn chân)
	_draw_capsule(canvas, hip + Vector2(dir * 1.5, 0.0), knee_f, 7.0, suit_mid)
	_draw_capsule(canvas, knee_f, foot_f, 5.4, suit_dark)
	var shin_mid := knee_f.lerp(foot_f, 0.38)
	_draw_capsule(canvas, shin_mid, foot_f, 5.0, wrap_col)
	canvas.draw_line(foot_f, foot_f + Vector2(dir * 6.0, 0.0), wrap_col.lightened(0.25), 3.8, true)

	# 5. Đầu, mũ/tóc võ sĩ, băng trán & đôi mắt phát sáng
	canvas.draw_circle(head, 6.4, suit_dark)
	if not use_override:
		# Khuôn mặt nhỏ & mắt phát sáng hướng về đối thủ
		canvas.draw_circle(head + Vector2(dir * 1.6, 0.5), 4.6, skin_col if not f.is_mirror_clone else Color(0.14, 0.16, 0.28, a))
		# Băng trán
		canvas.draw_line(
			head + Vector2(-5.8, -2.0),
			head + Vector2(5.8, -2.0),
			wrap_col,
			3.0,
			true
		)
		# Đôi mắt sáng sắc lạnh
		var eye_col := Color(1.0, 1.0, 1.0, a) if not f.is_mirror_clone else Color(0.55, 0.96, 1.0, a)
		canvas.draw_line(
			head + Vector2(dir * 1.8, -0.3),
			head + Vector2(dir * 5.2, -0.6),
			eye_col,
			2.1,
			true
		)
		# Giáp vai nhẹ (Archetype detail)
		if f.archetype == "rusher":
			var sp := shoulder + Vector2(-dir * 3.0, -2.0)
			canvas.draw_colored_polygon(PackedVector2Array([
				sp + Vector2(-4.0, 2.0),
				sp + Vector2(4.0, 2.0),
				sp + Vector2(-dir * 3.0, -5.0),
			]), wrap_col)
		elif f.archetype == "turtle":
			canvas.draw_circle(shoulder + Vector2(dir * 1.0, 0.5), 4.8, wrap_col.darkened(0.15))

	# 6. Tay trước (cánh tay + băng quấn cổ tay + nắm đấm rực sáng)
	_draw_capsule(canvas, shoulder + Vector2(dir * 1.0, 1.0), elbow_f, 5.6, suit_mid)
	_draw_capsule(canvas, elbow_f, hand_f, 4.8, wrap_col)
	canvas.draw_circle(hand_f, 3.4, wrap_col.lightened(0.32) if not use_override else suit_mid)

	# Viền ánh sáng (Rim light) cho nhân vật nổi bật trên nền tối
	if not use_override and not is_reflection:
		var rim := wrap_col.lightened(0.35)
		rim.a = 0.55 * a
		canvas.draw_arc(head, 6.7, -PI * 0.85, PI * 0.25, 12, rim, 1.3)

	# 7. Hiệu ứng Khiên Chắn (Block) & Vệt Đòn Đánh (Slash Arcs)
	if not use_override:
		if f.state == FighterCharacter.State.BLOCK:
			_draw_block_shield(canvas, dir, accent, anim_time, a)
		var sk: String = pose["slash_kind"]
		if sk != "":
			_draw_attack_slash(canvas, sk, float(pose["slash_progress"]), dir, hand_f, foot_f, accent, a)

	# 8. Chế độ bật/tắt Hitbox/Hurtbox chuẩn kỹ thuật (phím F2)
	if f.show_debug_boxes and not is_reflection and not use_override:
		var hurt := Rect2(-FighterCharacter.BODY_W * 0.5, -FighterCharacter.BODY_H, FighterCharacter.BODY_W, FighterCharacter.BODY_H)
		canvas.draw_rect(hurt, Color(0.2, 1.0, 0.4, 0.75), false, 1.5)
		if f.has_active_hitbox():
			var hb := f.get_hitbox()
			canvas.draw_rect(Rect2(hb.position - f.position, hb.size), Color(1.0, 0.22, 0.22, 0.45), true)
			canvas.draw_rect(Rect2(hb.position - f.position, hb.size), Color(1.0, 0.5, 0.3, 0.95), false, 1.8)


static func _draw_block_shield(canvas: CanvasItem, dir: float, accent: Color, anim_time: float, a: float) -> void:
	var cx := dir * (FighterCharacter.BODY_W * 0.5 + 8.0)
	var cy := -31.0
	var rx := 7.0
	var ry := 24.0
	var pulse := 0.85 + 0.15 * sin(anim_time * 12.0)
	var shield_col := accent.lightened(0.25)
	var poly := PackedVector2Array([
		Vector2(cx, cy - ry * pulse),
		Vector2(cx + dir * rx, cy - ry * 0.55),
		Vector2(cx + dir * (rx + 2.0), cy),
		Vector2(cx + dir * rx, cy + ry * 0.55),
		Vector2(cx, cy + ry * pulse),
		Vector2(cx - dir * 2.5, cy),
	])
	canvas.draw_colored_polygon(poly, Color(shield_col.r, shield_col.g, shield_col.b, 0.24 * a))
	var closed := poly.duplicate()
	closed.append(poly[0])
	canvas.draw_polyline(closed, Color(shield_col.r, shield_col.g, shield_col.b, 0.9 * a), 2.2, true)
	canvas.draw_line(
		Vector2(cx + dir * 2.5, cy - ry * 0.65),
		Vector2(cx + dir * 2.5, cy + ry * 0.65),
		Color(1.0, 1.0, 1.0, 0.75 * a),
		1.6
	)


static func _draw_attack_slash(
	canvas: CanvasItem,
	kind: String,
	progress: float,
	dir: float,
	hand_f: Vector2,
	foot_f: Vector2,
	accent: Color,
	a: float
) -> void:
	var glow := accent.lightened(0.22)
	var core := Color(1.0, 0.98, 0.92, 0.92 * a)
	if kind == "charge":
		# Tụ lực đòn Heavy ở nắm đấm
		var r := lerpf(4.0, 11.0, progress)
		canvas.draw_arc(hand_f, r, 0.0, TAU, 16, Color(glow.r, glow.g, glow.b, 0.65 * progress * a), 2.0)
		canvas.draw_circle(hand_f, 3.5 + progress * 3.0, Color(1.0, 0.95, 0.75, 0.75 * progress * a))
	elif kind == "light":
		# Vệt đấm thẳng sắc bén (tầm 14 -> 54 px)
		var tip := Vector2(dir * 54.0, -33.0)
		var base := Vector2(dir * 14.0, -34.0)
		var spear := PackedVector2Array([
			base + Vector2(0.0, -5.5),
			tip,
			base + Vector2(0.0, 5.5),
			base + Vector2(dir * 10.0, 0.0),
		])
		canvas.draw_colored_polygon(spear, Color(glow.r, glow.g, glow.b, 0.68 * a))
		canvas.draw_line(base + Vector2(dir * 6.0, 0.0), tip, core, 2.8, true)
	elif kind == "heavy":
		# Sóng xung kích đấm mạnh (tầm 14 -> 64 px, cao -52..-14)
		var cx := dir * 22.0
		var cy := -33.0
		var rx := 42.0
		var ry := 20.0
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var steps := 10
		for i in range(steps + 1):
			var th := lerpf(-PI * 0.44, PI * 0.44, float(i) / float(steps))
			outer.append(Vector2(cx + dir * cos(th) * rx, cy + sin(th) * ry))
			inner.append(Vector2(cx + dir * cos(th) * (rx * 0.56), cy + sin(th) * (ry * 0.65)))
		var crescent := PackedVector2Array()
		crescent.append_array(outer)
		for i in range(steps, -1, -1):
			crescent.append(inner[i])
		canvas.draw_colored_polygon(crescent, Color(glow.r, glow.g, glow.b, 0.75 * a))
		canvas.draw_polyline(outer, core, 3.2, true)
		canvas.draw_circle(hand_f, 6.5, Color(1.0, 0.95, 0.8, 0.85 * a))
	elif kind == "kick":
		# Vệt cước vòng cung tầm xa (tầm 14 -> 86 px, cao -30..-2)
		var cx := dir * 18.0
		var cy := -16.0
		var rx := 68.0
		var ry := 15.0
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var steps := 12
		for i in range(steps + 1):
			var th := lerpf(-PI * 0.38, PI * 0.42, float(i) / float(steps))
			outer.append(Vector2(cx + dir * cos(th) * rx, cy + sin(th) * ry))
			inner.append(Vector2(cx + dir * cos(th) * (rx * 0.58), cy + sin(th) * (ry * 0.55)))
		var blade := PackedVector2Array()
		blade.append_array(outer)
		for i in range(steps, -1, -1):
			blade.append(inner[i])
		canvas.draw_colored_polygon(blade, Color(glow.r, glow.g, glow.b, 0.72 * a))
		canvas.draw_polyline(outer, core, 2.8, true)
		canvas.draw_circle(foot_f, 4.8, core)
