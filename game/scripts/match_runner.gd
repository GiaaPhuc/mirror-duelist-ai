extends Node
## Chạy N trận headless giữa hai controller bất kỳ (random, rusher, turtle, poker, mirror),
## kiểm tra bất biến luật game, ghi log quyết định (DataLogger) và xuất kết quả trận ra CSV.
##
## Ví dụ:
##   godot --headless --path game --scene res://scenes/headless_matches.tscn -- \
##     --p1=rusher --p2=rotate --matches=500 --results-csv=data/raw/matches.csv --log-csv=data/raw/rusher.csv

const DEFAULT_MATCHES := 100
const ROTATE_POOL: PackedStringArray = ["rusher", "turtle", "poker", "random"]


func _ready() -> void:
	var cfg := _parse_args(OS.get_cmdline_user_args())
	var code := run_with_config(cfg)
	get_tree().quit(code)


## Giữ tương thích ngược với cách gọi `run(n)` của Tuần 2.
func run(n: int) -> int:
	var cfg := _default_config()
	cfg["matches"] = n
	return run_with_config(cfg)


func _default_config() -> Dictionary:
	return {
		"matches": DEFAULT_MATCHES,
		"p1": "random",
		"p2": "random",
		"model": MirrorController.DEFAULT_MODEL_PATH,
		"seed": 1,
		"epsilon": 0.12,
		"temperature": 0.7,
		"results_csv": "",
		"log_csv": "",
		"log_append": false,
		"log_side": "p1",
		"min_rows": 0,
		"session_prefix": "",
	}


func _parse_args(args: PackedStringArray) -> Dictionary:
	var cfg := _default_config()
	for arg in args:
		if arg.begins_with("--matches="):
			cfg["matches"] = int(arg.substr(10))
		elif arg.begins_with("--p1="):
			cfg["p1"] = arg.substr(5).strip_edges().to_lower()
		elif arg.begins_with("--p2="):
			cfg["p2"] = arg.substr(5).strip_edges().to_lower()
		elif arg.begins_with("--model="):
			cfg["model"] = arg.substr(8).strip_edges()
		elif arg.begins_with("--seed="):
			cfg["seed"] = int(arg.substr(7))
		elif arg.begins_with("--epsilon="):
			cfg["epsilon"] = float(arg.substr(10))
		elif arg.begins_with("--temperature="):
			cfg["temperature"] = float(arg.substr(14))
		elif arg.begins_with("--results-csv="):
			cfg["results_csv"] = arg.substr(14).strip_edges()
		elif arg.begins_with("--log-csv="):
			cfg["log_csv"] = arg.substr(10).strip_edges()
		elif arg == "--log-append":
			cfg["log_append"] = true
		elif arg.begins_with("--log-side="):
			cfg["log_side"] = arg.substr(11).strip_edges().to_lower()
		elif arg.begins_with("--min-rows="):
			cfg["min_rows"] = int(arg.substr(11))
		elif arg.begins_with("--session-prefix="):
			cfg["session_prefix"] = arg.substr(17).strip_edges()
	return cfg


func make_controller(spec: String, seed_val: int, cfg: Dictionary) -> Controller:
	var s := spec.to_lower()
	var eps: float = float(cfg["epsilon"])
	var temp: float = float(cfg["temperature"])
	var model_path: String = str(cfg["model"])
	if s.begins_with("mirror:"):
		model_path = spec.substr(7)
		s = "mirror"

	match s:
		"rusher":
			return BotRusher.new(seed_val, eps)
		"turtle":
			return BotTurtle.new(seed_val, eps)
		"poker":
			return BotPoker.new(seed_val, eps)
		"mirror":
			return MirrorController.new(model_path, seed_val, temp)
		"random", _:
			return RandomController.new(seed_val)


func run_with_config(cfg: Dictionary) -> int:
	var started := Time.get_ticks_msec()
	var n: int = int(cfg["matches"])
	var min_rows: int = int(cfg["min_rows"])
	var base_seed: int = int(cfg["seed"])
	var p1_spec: String = str(cfg["p1"])
	var p2_spec: String = str(cfg["p2"])
	var log_csv: String = str(cfg["log_csv"])
	var results_csv: String = str(cfg["results_csv"])
	var log_side: String = str(cfg["log_side"])
	var prefix: String = str(cfg["session_prefix"])

	var logger: DataLogger = null
	if log_csv != "":
		logger = DataLogger.new()
		if not logger.open(log_csv, bool(cfg["log_append"])):
			printerr("MATCH_RUNNER_FAIL: không mở được file log CSV: " + log_csv)
			return 1

	var res_file: FileAccess = null
	if results_csv != "":
		var resolved_res := DataLogger.resolve_path(results_csv)
		var base_dir := resolved_res.get_base_dir()
		if base_dir != "":
			DirAccess.make_dir_recursive_absolute(base_dir)
		res_file = FileAccess.open(resolved_res, FileAccess.WRITE)
		if res_file == null:
			printerr("MATCH_RUNNER_FAIL: không mở được file results CSV: " + results_csv)
			if logger != null:
				logger.close()
			return 1
		res_file.store_line("match_id,session_id,p1,p2,winner,hp_a,hp_b,ticks,reason")

	var errors: Array[String] = []
	var wins := [0, 0, 0] # A, B, hoà
	var kos := 0
	var timeouts := 0
	var total_ticks := 0
	var max_guard := GameConstants.ROUND_TIME_TICKS + 5
	var max_matches_cap := maxi(n, 5000) if min_rows > 0 else n

	var i := 0
	while i < n or (logger != null and min_rows > 0 and logger.rows_written < min_rows and i < max_matches_cap):
		var actual_p2 := p2_spec
		if p2_spec == "rotate":
			actual_p2 = ROTATE_POOL[i % ROTATE_POOL.size()]

		var ctrl_a := make_controller(p1_spec, base_seed + i * 2, cfg)
		var ctrl_b := make_controller(actual_p2, base_seed + i * 2 + 1, cfg)
		if (p1_spec.begins_with("mirror") and not (ctrl_a as MirrorController).is_loaded()) \
				or (actual_p2.begins_with("mirror") and not (ctrl_b as MirrorController).is_loaded()):
			errors.append("không nạp được model JSON cho MirrorController (%s)" % str(cfg["model"]))
			break

		var a := FighterCharacter.new()
		var b := FighterCharacter.new()
		var m := FightMatch.new(a, b, ctrl_a, ctrl_b)
		var sid := "%s_%s_vs_%s_%04d" % [
			prefix if prefix != "" else "sess",
			p1_spec.get_slice(":", 0),
			actual_p2.get_slice(":", 0),
			i
		]
		if logger != null:
			var log_p1 := (log_side == "p1" or log_side == "both")
			var log_p2 := (log_side == "p2" or log_side == "both")
			m.configure_logging(
				logger,
				sid,
				p1_spec.get_slice(":", 0),
				actual_p2.get_slice(":", 0),
				log_p1,
				log_p2
			)
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
			if res_file != null:
				res_file.store_line("%d,%s,%s,%s,%d,%.2f,%.2f,%d,%s" % [
					i,
					sid,
					p1_spec.get_slice(":", 0),
					actual_p2.get_slice(":", 0),
					w,
					float(r["hp_a"]),
					float(r["hp_b"]),
					int(r["ticks"]),
					str(r["reason"]),
				])
		a.free()
		b.free()
		i += 1
		if errors.size() > 10:
			break

	var rows_logged := logger.rows_written if logger != null else 0
	if logger != null:
		logger.close()
	if res_file != null:
		res_file.flush()
		res_file = null

	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("MATCH_RUNNER p1=%s p2=%s matches=%d A=%d B=%d draw=%d ko=%d timeout=%d avg_ticks=%.0f rows=%d time=%.2fs" % [
		p1_spec, p2_spec, i, wins[0], wins[1], wins[2], kos, timeouts,
		float(total_ticks) / maxf(i, 1), rows_logged, elapsed
	])
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
