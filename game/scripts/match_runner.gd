extends Node
## Chạy N trận headless giữa hai controller ngẫu nhiên và kiểm tra luật.
## godot --headless --path game --scene res://scenes/headless_matches.tscn -- --matches=100
## Thoát 0 nếu mọi trận hợp lệ, 1 nếu có lỗi.

const DEFAULT_MATCHES := 100


func _ready() -> void:
	var n := DEFAULT_MATCHES
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matches="):
			n = int(arg.substr(10))
	var code := run(n)
	get_tree().quit(code)


func run(n: int) -> int:
	var started := Time.get_ticks_msec()
	var errors: Array[String] = []
	var wins := [0, 0, 0] # A, B, hoà
	var kos := 0
	var timeouts := 0
	var total_ticks := 0
	var max_guard := GameConstants.ROUND_TIME_TICKS + 5

	for i in n:
		var a := FighterCharacter.new()
		var b := FighterCharacter.new()
		var m := FightMatch.new(a, b, RandomController.new(i * 2 + 1), RandomController.new(i * 2 + 2))
		m.reset()
		var guard := 0
		while not m.finished and guard < max_guard:
			m.step()
			guard += 1
			var err := _check_invariants(m)
			if err != "":
				errors.append("match %d tick %d: %s" % [i, m.tick_count, err])
				break
		if not m.finished:
			errors.append("match %d không kết thúc (tick=%d)" % [i, m.tick_count])
		else:
			var r := m.result
			total_ticks += int(r["ticks"])
			if r["reason"] == "ko":
				kos += 1
			else:
				timeouts += 1
			var w := int(r["winner"])
			wins[w if w >= 0 else 2] += 1
			var err2 := _check_result(r)
			if err2 != "":
				errors.append("match %d: %s" % [i, err2])
		a.free()
		b.free()
		if errors.size() > 10:
			break

	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("MATCH_RUNNER matches=%d A=%d B=%d draw=%d ko=%d timeout=%d avg_ticks=%.0f time=%.1fs" % [
		n, wins[0], wins[1], wins[2], kos, timeouts, float(total_ticks) / maxf(n, 1), elapsed])
	if errors.is_empty():
		print("MATCH_RUNNER_OK")
		return 0
	for e in errors:
		printerr("MATCH_RUNNER_FAIL: " + e)
	return 1


func _check_invariants(m: FightMatch) -> String:
	for f in m.fighters:
		if is_nan(f.position.x) or is_nan(f.position.y) or is_nan(f.velocity.x) or is_nan(f.velocity.y):
			return "NaN"
		if f.hp < 0.0 or f.hp > GameConstants.MAX_HP:
			return "hp ngoài [0,100]: %f" % f.hp
		var lim := GameConstants.ARENA_WALL_HALF
		if absf(f.position.x) > lim or f.position.y > GameConstants.ARENA_FLOOR_Y + 0.01:
			return "ra ngoài arena: %s" % f.position
	var s := StateEncoder.encode(m.fighters[0], m.fighters[1])
	if s.size() != GameConstants.N_STATE:
		return "state sai kích thước"
	for v in s:
		if is_nan(v) or v < -1.0001 or v > 1.0001:
			return "state ngoài [-1,1]"
	return ""


func _check_result(r: Dictionary) -> String:
	var hp_a: float = r["hp_a"]
	var hp_b: float = r["hp_b"]
	var expected := -1
	if hp_a > hp_b:
		expected = 0
	elif hp_b > hp_a:
		expected = 1
	if int(r["winner"]) != expected:
		return "người thắng sai luật HP"
	if r["reason"] == "ko" and hp_a > 0.0 and hp_b > 0.0:
		return "KO nhưng không ai hết HP"
	if r["reason"] == "timeout" and int(r["ticks"]) != GameConstants.ROUND_TIME_TICKS:
		return "timeout sai số tick"
	return ""
