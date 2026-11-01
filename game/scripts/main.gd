extends Node2D
## Điều phối chính của Mirror Duelist:
## - Kết nối Đền Gương (Arena), 2 Võ sĩ (FighterCharacter), Hiệu ứng (VfxManager),
##   HUD chiến đấu (Hud) và Giao diện Menu / Thống kê hậu trận (UiOverlay).
## - Tự động ghi log hành vi người chơi (10 Hz, khi actionable) vào `data/raw/human_self.csv`.

const HUMAN_LOG_CSV := "data/raw/human_self.csv"
const CAMERA_BASE_POS := Vector2(0.0, 360.0)

const WATCH_PAIRS := [
	{"label": "Mirror-Rusher vs Rusher", "p1_name": "MIRROR-RUSHER", "p2_name": "BOT RUSHER", "model": "data/models/mirror_rusher.json", "bot": "rusher"},
	{"label": "Mirror-Turtle vs Turtle", "p1_name": "MIRROR-TURTLE", "p2_name": "BOT TURTLE", "model": "data/models/mirror_turtle.json", "bot": "turtle"},
	{"label": "Mirror-Poker vs Poker", "p1_name": "MIRROR-POKER", "p2_name": "BOT POKER", "model": "data/models/mirror_poker.json", "bot": "poker"},
]

@onready var _arena: Node2D = $Arena
@onready var _p1: FighterCharacter = $Fighter
@onready var _p2: FighterCharacter = $Opponent
@onready var _vfx: VfxManager = $Vfx
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: Node2D = $UI/Hud
@onready var _overlay: UiOverlay = $UI/Overlay

var _match: FightMatch
var _opp_name: String = "Rusher"
var _current_mode_id: String = "rusher"
var _logger: DataLogger = DataLogger.new()
var _existing_csv_rows: int = 0
var _human_session_seq: int = 0

var _watch_mode: bool = false
var _watch_idx: int = 0
var _attract_mode: bool = true
var _paused_in_menu: bool = false

var _flushed_current_match: bool = false
var _post_match_shown: bool = false
var _post_match_delay: float = 0.0
var _cam_focus: Vector2 = CAMERA_BASE_POS
var _cam_zoom: float = 1.0

# Thống kê hành vi & chiến đấu trong trận hiện tại
var _dmg_dealt: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _hits_landed: PackedInt32Array = PackedInt32Array([0, 0])
var _blocks_made: PackedInt32Array = PackedInt32Array([0, 0])
var _max_combo: PackedInt32Array = PackedInt32Array([0, 0])
var _dist_sum: float = 0.0
var _dist_samples: int = 0
var _action_hist: Array = [[], []]


func _ready() -> void:
	var f_list: Array[FighterCharacter] = [_p1, _p2]
	_arena.fighters = f_list
	_existing_csv_rows = _count_existing_csv_rows(HUMAN_LOG_CSV)
	_logger.open(HUMAN_LOG_CSV, true)

	_overlay.mode_selected.connect(_on_mode_selected)
	_overlay.resume_requested.connect(_on_resume_requested)
	_overlay.rematch_requested.connect(_restart_current_mode)
	_overlay.open_menu_requested.connect(_open_main_menu)

	_update_sample_counters()
	_start_attract_demo()
	_overlay.can_resume = false
	_overlay.set_screen(UiOverlay.ScreenMode.MAIN_MENU)
	_hud.hud_visible_in_menu = true

	if DisplayServer.get_name() == "headless":
		print("Mirror Duelist: headless session (main scene). Dùng headless_test.tscn / headless_matches.tscn.")


func _exit_tree() -> void:
	if _logger != null:
		_logger.close()


func _count_existing_csv_rows(path: String) -> int:
	var resolved := DataLogger.resolve_path(path)
	if not FileAccess.file_exists(resolved):
		return 0
	var f := FileAccess.open(resolved, FileAccess.READ)
	if f == null:
		return 0
	var count := 0
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "" and not line.begins_with("session_id"):
			count += 1
	return count


func _total_samples() -> int:
	var added := _logger.rows_written if _logger != null else 0
	return _existing_csv_rows + added


func _update_sample_counters() -> void:
	var total := _total_samples()
	_hud.sample_count = total
	_overlay.total_human_samples = total


func _reset_match_stats() -> void:
	_dmg_dealt = PackedFloat32Array([0.0, 0.0])
	_hits_landed = PackedInt32Array([0, 0])
	_blocks_made = PackedInt32Array([0, 0])
	_max_combo = PackedInt32Array([0, 0])
	_dist_sum = 0.0
	_dist_samples = 0
	_action_hist = [
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	]
	_flushed_current_match = false
	_post_match_shown = false
	_post_match_delay = 0.0


func _make_mirror_or_fallback(path: String) -> MirrorController:
	var ctrl := MirrorController.new(path, randi())
	if not ctrl.is_loaded() and path != MirrorController.DEFAULT_MODEL_PATH:
		ctrl.load_model(MirrorController.DEFAULT_MODEL_PATH)
	return ctrl


func _start_attract_demo() -> void:
	_attract_mode = true
	_watch_mode = false
	_paused_in_menu = false
	_arena.mirror_realm_active = true
	_vfx.clear_all()
	_reset_match_stats()

	_p1.configure_visuals("player", false, "VÕ SĨ ÁNH SÁNG", "Luyện Tập")
	_p2.configure_visuals("mirror", true, "BẢN SAO GƯƠNG", "Behavior Cloning")

	var ctrl_a := BotRusher.new(randi())
	var mirror_b := _make_mirror_or_fallback("data/models/mirror_rusher.json")
	var ctrl_b: Controller = mirror_b if mirror_b.is_loaded() else BotPoker.new(randi())
	_match = FightMatch.new(_p1, _p2, ctrl_a, ctrl_b)
	_match.reset()
	_hud.fight = _match
	_hud.reset_bars()


func _on_mode_selected(mode_id: String) -> void:
	match mode_id:
		"rusher":
			_start_human_match("rusher", "Rusher", "BOT RUSHER", "Cuồng Chiến Áp Sát", false, BotRusher.new(randi()))
		"turtle":
			_start_human_match("turtle", "Turtle", "BOT TURTLE", "Thiết Giáp Phản Đòn", false, BotTurtle.new(randi()))
		"poker":
			_start_human_match("poker", "Poker", "BOT POKER", "Phong Cước Tầm Xa", false, BotPoker.new(randi()))
		"random":
			_start_human_match("random", "Random", "BOT RANDOM", "Thử Nghiệm Ngẫu Nhiên", false, RandomController.new(randi()))
		"mirror":
			_start_human_match("mirror", "Mirror", "MIRROR AI", "Bản Sao Mặc Định", true, _make_mirror_or_fallback(MirrorController.DEFAULT_MODEL_PATH))
		"mirror_rusher":
			_start_human_match("mirror_rusher", "Mirror-Rusher", "MIRROR-RUSHER", "Học Từ Rusher", true, _make_mirror_or_fallback("data/models/mirror_rusher.json"))
		"mirror_turtle":
			_start_human_match("mirror_turtle", "Mirror-Turtle", "MIRROR-TURTLE", "Học Từ Turtle", true, _make_mirror_or_fallback("data/models/mirror_turtle.json"))
		"mirror_poker":
			_start_human_match("mirror_poker", "Mirror-Poker", "MIRROR-POKER", "Học Từ Poker", true, _make_mirror_or_fallback("data/models/mirror_poker.json"))
		"mirror_self":
			_start_human_match("mirror_self", "Mirror-Self", "MIRROR-SELF", "Bản Sao Của Chính Bạn", true, _make_mirror_or_fallback("data/models/mirror_human_self.json"))
		"watch":
			if _watch_mode and not _attract_mode:
				_watch_idx = (_watch_idx + 1) % WATCH_PAIRS.size()
			_start_watch_match(_watch_idx)


func _start_human_match(
	mode_id: String,
	opp_label: String,
	p2_title: String,
	p2_sub: String,
	is_mirror: bool,
	opp_ctrl: Controller
) -> void:
	_attract_mode = false
	_watch_mode = false
	_paused_in_menu = false
	_current_mode_id = mode_id
	_opp_name = opp_label
	_human_session_seq += 1
	_reset_match_stats()
	_vfx.clear_all()

	_arena.mirror_realm_active = is_mirror
	_p1.configure_visuals("player", false, "NGƯỜI CHƠI", "Võ Sĩ Ánh Sáng")
	_p2.configure_visuals(opp_label.to_lower(), is_mirror, p2_title, p2_sub)

	var sid := "human_self_vs_%s_%d_%02d" % [
		opp_label.to_lower().replace("-", "_"),
		int(Time.get_unix_time_from_system()),
		_human_session_seq
	]
	_match = FightMatch.new(_p1, _p2, HumanController.new(), opp_ctrl)
	if _logger != null and _logger.is_open():
		_match.configure_logging(_logger, sid, "human_self", opp_label.to_lower(), true, false)
	_match.reset()

	_hud.fight = _match
	_hud.mode_badge = "GƯƠNG ĐẤU" if is_mirror else "LUYỆN TẬP"
	_hud.hud_visible_in_menu = false
	_hud.reset_bars()
	_overlay.can_resume = true
	_overlay.set_screen(UiOverlay.ScreenMode.NONE)

	if is_mirror:
		_hud.show_banner("GƯƠNG ĐẤU", "ĐỐI THỦ LÀ BẢN SAO HÀNH VI — HÃY VƯỢT QUA CHÍNH MÌNH!", Color(0.55, 0.88, 1.0), 1.65)
	else:
		_hud.show_banner("HIỆP %d — CHIẾN!" % _human_session_seq, "Đấu với %s • Đang ghi dữ liệu phong cách 10 Hz" % p2_title, _p2.accent_color, 1.35)


func _start_watch_match(pair_idx: int) -> void:
	_attract_mode = false
	_watch_mode = true
	_paused_in_menu = false
	_current_mode_id = "watch"
	var cfg: Dictionary = WATCH_PAIRS[pair_idx % WATCH_PAIRS.size()]
	_opp_name = str(cfg["label"])
	_reset_match_stats()
	_vfx.clear_all()

	var bot_name := str(cfg["bot"])
	_arena.mirror_realm_active = true
	_p1.configure_visuals("mirror", true, str(cfg["p1_name"]), "Mạng MLP (BC)")
	_p2.configure_visuals(bot_name, false, str(cfg["p2_name"]), "Bot Nguyên Mẫu")

	var ctrl_a := _make_mirror_or_fallback(str(cfg["model"]))
	var ctrl_b: Controller
	match bot_name:
		"turtle":
			ctrl_b = BotTurtle.new(randi())
		"poker":
			ctrl_b = BotPoker.new(randi())
		_:
			ctrl_b = BotRusher.new(randi())

	_match = FightMatch.new(_p1, _p2, ctrl_a, ctrl_b)
	_match.reset()

	_hud.fight = _match
	_hud.mode_badge = "XEM AI ĐẤU"
	_hud.show_ai_panel = true
	_hud.hud_visible_in_menu = false
	_hud.reset_bars()
	_overlay.can_resume = true
	_overlay.set_screen(UiOverlay.ScreenMode.NONE)
	_hud.show_banner(str(cfg["label"]).to_upper(), "So sánh trực quan hành vi mạng MLP và Bot gốc", Color(0.52, 0.90, 1.0), 1.5)


func _restart_current_mode() -> void:
	if _attract_mode:
		_on_mode_selected("rusher")
		return
	if _watch_mode:
		_start_watch_match(_watch_idx)
		return
	_on_mode_selected(_current_mode_id)


func _open_main_menu() -> void:
	_update_sample_counters()
	if not _attract_mode and _match != null and not _match.finished:
		_paused_in_menu = true
		_overlay.can_resume = true
	else:
		_paused_in_menu = false
		_overlay.can_resume = false
	_hud.hud_visible_in_menu = true
	_overlay.set_screen(UiOverlay.ScreenMode.MAIN_MENU)


func _on_resume_requested() -> void:
	if not _attract_mode and _match != null and not _match.finished:
		_paused_in_menu = false
		_hud.hud_visible_in_menu = false
		_overlay.set_screen(UiOverlay.ScreenMode.NONE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _overlay.screen_mode == UiOverlay.ScreenMode.NONE:
			if Rect2(1160.0, 686.0, 120.0, 34.0).has_point(mb.position):
				_open_main_menu()
				get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).physical_keycode

	if key == KEY_ESCAPE:
		if _overlay.screen_mode == UiOverlay.ScreenMode.MAIN_MENU:
			if _overlay.can_resume:
				_on_resume_requested()
		else:
			_open_main_menu()
		return

	if key == KEY_TAB:
		_hud.show_ai_panel = not _hud.show_ai_panel
		return

	if key == KEY_F2:
		var next_dbg := not _p1.show_debug_boxes
		_p1.show_debug_boxes = next_dbg
		_p2.show_debug_boxes = next_dbg
		return

	if key == KEY_1:
		_on_mode_selected("rusher")
	elif key == KEY_2:
		_on_mode_selected("turtle")
	elif key == KEY_3:
		_on_mode_selected("poker")
	elif key == KEY_4:
		_on_mode_selected("mirror")
	elif key == KEY_5:
		_on_mode_selected("mirror_rusher")
	elif key == KEY_6:
		_on_mode_selected("mirror_turtle")
	elif key == KEY_7:
		_on_mode_selected("mirror_poker")
	elif key == KEY_8:
		_on_mode_selected("mirror_self")
	elif key == KEY_9:
		_on_mode_selected("watch")
	elif key == KEY_0:
		_on_mode_selected("random")
	elif key == KEY_R:
		if _overlay.screen_mode != UiOverlay.ScreenMode.MAIN_MENU:
			_restart_current_mode()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		if _match != null and _match.finished and not _attract_mode:
			_restart_current_mode()


func _physics_process(delta: float) -> void:
	if _match == null or _paused_in_menu:
		return

	if _match.finished:
		if _attract_mode:
			_start_attract_demo()
			return
		if not _flushed_current_match:
			if _logger != null:
				_logger.flush()
			_flushed_current_match = true
			_update_sample_counters()
			_on_match_just_finished()
		elif not _post_match_shown:
			_post_match_delay += delta
			if _post_match_delay >= 0.95:
				_post_match_shown = true
				_overlay.show_post_match(_build_post_match_summary())
		return

	# Snapshot trạng thái trước tick để kích hoạt VFX & thống kê chính xác
	var hp_prev := PackedFloat32Array([_p1.hp, _p2.hp])
	var st_prev := [_p1.state, _p2.state]
	var gr_prev := [_p1.is_on_floor(), _p2.is_on_floor()]

	_match.step()

	_observe_tick_events(hp_prev, st_prev, gr_prev)


func _observe_tick_events(hp_prev: PackedFloat32Array, st_prev: Array, gr_prev: Array) -> void:
	var fighters := [_p1, _p2]

	# Ghi thống kê phân phối hành động & khoảng cách ở 10 Hz
	if _match.tick_count % GameConstants.DECISION_INTERVAL_FRAMES == 0:
		_dist_sum += absf(_p1.position.x - _p2.position.x)
		_dist_samples += 1
		for i in 2:
			var f: FighterCharacter = fighters[i]
			var act := _infer_current_action(f)
			if act >= 0 and act < 10:
				_action_hist[i][act] = int(_action_hist[i][act]) + 1

	for i in 2:
		var def: FighterCharacter = fighters[i]
		var atk: FighterCharacter = fighters[1 - i]
		var dmg := hp_prev[i] - def.hp
		if dmg > 0.005:
			_dmg_dealt[1 - i] += dmg
			var impact := Vector2(lerpf(def.position.x, atk.position.x, 0.35), def.position.y - 33.0)
			if def.state == FighterCharacter.State.STUN:
				_hits_landed[1 - i] += 1
				_max_combo[1 - i] = maxi(_max_combo[1 - i], atk.combo)
				_vfx.spawn_hit_effect(impact, dmg, atk.current_action, atk.accent_color, atk.combo, def.hp <= 0.0)
				_vfx.spawn_dust(def.position, -float(def.facing), 5)
			else:
				_blocks_made[i] += 1
				_vfx.spawn_block_effect(impact, dmg)

		# Nhảy lên / Tiếp đất
		var now_grounded := def.is_on_floor()
		if bool(gr_prev[i]) and not now_grounded and def.velocity.y < -100.0:
			_vfx.spawn_dust(Vector2(def.position.x, GameConstants.ARENA_FLOOR_Y), 0.0, 5)
		elif not bool(gr_prev[i]) and now_grounded:
			_vfx.spawn_dust(Vector2(def.position.x, GameConstants.ARENA_FLOOR_Y), 0.0, 6)

		# Khởi đầu Lướt (Dash) / Né (Dodge)
		if st_prev[i] != def.state:
			if def.state == FighterCharacter.State.DASH:
				_vfx.spawn_dust(def.position, float(def.facing), 7, def.accent_color)
			elif def.state == FighterCharacter.State.DODGE:
				_vfx.spawn_dust(def.position, -float(def.facing), 6, def.accent_color)

		# Tàn ảnh bóng mờ khi Dash, Dodge hoặc tung đòn mạnh/cước
		if _match.tick_count % 2 == 0:
			if def.state == FighterCharacter.State.DASH or def.state == FighterCharacter.State.DODGE:
				_vfx.spawn_afterimage(def)
			elif def.state == FighterCharacter.State.ATTACK and def.has_active_hitbox() and def.current_action != GameConstants.ACTION_LIGHT:
				_vfx.spawn_afterimage(def)

		# Hạt ánh gương bay quanh AI Mirror
		if def.is_mirror_clone and _match.tick_count % 8 == 0:
			_vfx.spawn_mirror_wisp(def)


func _infer_current_action(f: FighterCharacter) -> int:
	if f.state == FighterCharacter.State.ATTACK or f.state == FighterCharacter.State.DASH or f.state == FighterCharacter.State.DODGE:
		return f.current_action
	if f.state == FighterCharacter.State.BLOCK:
		return GameConstants.ACTION_BLOCK
	if not f.is_on_floor():
		return GameConstants.ACTION_JUMP
	return f.intent


func _on_match_just_finished() -> void:
	var r := _match.result
	var is_ko := str(r.get("reason", "")) == "ko"
	var w := int(r.get("winner", -1))
	var col := Color(0.95, 0.85, 0.35)
	if w == 0:
		col = _p1.accent_color
	elif w == 1:
		col = _p2.accent_color
	var sub := "Hoàn tất hiệp đấu!"
	if w == 0:
		sub = ("%s giành chiến thắng!" % _p1.display_name)
	elif w == 1:
		sub = ("%s giành chiến thắng!" % _p2.display_name)
	_hud.show_banner("K.O.!" if is_ko else "HẾT GIỜ!", sub, col, 1.0)


func _build_post_match_summary() -> Dictionary:
	var r := _match.result
	var w := int(r.get("winner", -1))
	var headline := "TRẬN ĐẤU HOÀ!"
	var b_col := Color(0.95, 0.84, 0.38)
	if w == 0:
		headline = ("%s THẮNG!" % _p1.display_name) if _watch_mode else "BẠN CHIẾN THẮNG!"
		b_col = _p1.accent_color
	elif w == 1:
		headline = ("%s THẮNG!" % _p2.display_name) if _watch_mode else ("BẢN SAO GƯƠNG THẮNG!" if _p2.is_mirror_clone else "ĐỐI THỦ CHIẾN THẮNG!")
		b_col = _p2.accent_color

	var dur_sec := float(int(r.get("ticks", 0))) / float(GameConstants.TARGET_FPS)
	var reason_vi := "Hạ đo ván (K.O.)" if str(r.get("reason", "")) == "ko" else "Hết thời gian (60s)"
	var subline := "%s sau %.1fs  •  Máu còn lại: %.0f HP vs %.0f HP  •  Tổng mẫu đã ghi: %d" % [
		reason_vi, dur_sec, _p1.hp, _p2.hp, _total_samples()
	]

	var avg_dist := (_dist_sum / float(_dist_samples)) if _dist_samples > 0 else 240.0
	var sim_pct := _compute_cosine_similarity(_action_hist[0], _action_hist[1]) * 100.0

	var metrics := [
		{"label": "Tổng sát thương gây ra", "p1": "%.0f" % _dmg_dealt[0], "p2": "%.0f" % _dmg_dealt[1]},
		{"label": "Số đòn đánh trúng đích", "p1": "%d đòn" % _hits_landed[0], "p2": "%d đòn" % _hits_landed[1]},
		{"label": "Đỡ đòn thành công (Block)", "p1": "%d lần" % _blocks_made[0], "p2": "%d lần" % _blocks_made[1]},
		{"label": "Chuỗi Combo cao nhất", "p1": "%d hits" % _max_combo[0], "p2": "%d hits" % _max_combo[1]},
	]

	var t0 := _sum_int_array(_action_hist[0])
	var t1 := _sum_int_array(_action_hist[1])
	var groups := [
		{"name": "Di chuyển (A/D)", "indices": [1, 2]},
		{"name": "Nhảy (W)", "indices": [3]},
		{"name": "Đấm nhẹ (J)", "indices": [4]},
		{"name": "Đấm mạnh (K)", "indices": [5]},
		{"name": "Đá tầm xa (L)", "indices": [6]},
		{"name": "Thủ / Né / Lướt", "indices": [7, 8, 9]},
	]
	var dist_rows: Array = []
	for g in groups:
		var s0 := 0
		var s1 := 0
		for idx in g["indices"]:
			s0 += int(_action_hist[0][idx])
			s1 += int(_action_hist[1][idx])
		dist_rows.append({
			"name": g["name"],
			"p1_pct": (100.0 * float(s0) / float(maxi(t0, 1))),
			"p2_pct": (100.0 * float(s1) / float(maxi(t1, 1))),
		})

	return {
		"headline": headline,
		"subline": subline,
		"banner_color": b_col,
		"p1_name": _p1.display_name,
		"p2_name": _p2.display_name,
		"p1_col": _p1.accent_color,
		"p2_col": _p2.accent_color,
		"avg_dist": avg_dist,
		"similarity_pct": sim_pct,
		"metrics": metrics,
		"dist_rows": dist_rows,
		"watch_mode": _watch_mode,
	}


func _sum_int_array(arr: Array) -> int:
	var s := 0
	for v in arr:
		s += int(v)
	return s


func _compute_cosine_similarity(a: Array, b: Array) -> float:
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for i in mini(a.size(), b.size()):
		var va := float(a[i])
		var vb := float(b[i])
		dot += va * vb
		na += va * va
		nb += vb * vb
	if na <= 1e-9 or nb <= 1e-9:
		return 0.0
	return clampf(dot / (sqrt(na) * sqrt(nb)), 0.0, 1.0)


func _process(delta: float) -> void:
	var target_pos := CAMERA_BASE_POS
	var target_zoom := 1.0
	if not _attract_mode and _overlay.screen_mode == UiOverlay.ScreenMode.NONE:
		var mid_x := clampf((_p1.position.x + _p2.position.x) * 0.5, -135.0, 135.0)
		var sep := absf(_p1.position.x - _p2.position.x)
		var t_sep := clampf((sep - 130.0) / 420.0, 0.0, 1.0)
		target_zoom = lerpf(1.22, 1.06, t_sep)
		target_pos = Vector2(mid_x, lerpf(396.0, 368.0, t_sep))
	_cam_focus = _cam_focus.lerp(target_pos, clampf(delta * 6.5, 0.0, 1.0))
	_cam_zoom = lerpf(_cam_zoom, target_zoom, clampf(delta * 5.5, 0.0, 1.0))
	if _camera != null:
		_camera.zoom = Vector2(_cam_zoom, _cam_zoom)
	_vfx.update_camera(_camera, _cam_focus, delta)
	if not _attract_mode and _match != null and _match.tick_count % 30 == 0:
		_update_sample_counters()
