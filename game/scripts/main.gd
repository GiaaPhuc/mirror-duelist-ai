extends Node2D
## Trận người vs AI (tự động ghi log vào data/raw/human_self.csv ở 10 Hz khi actionable)
## và chế độ quan sát trực quan Mirror-X đấu Bot-X (phím 9).
##
## Phím tắt:
##   1: Rusher · 2: Turtle · 3: Poker · 4: Mirror (mặc định)
##   5: Mirror-Rusher · 6: Mirror-Turtle · 7: Mirror-Poker · 8: Mirror-Self
##   9: Xem trực quan Mirror-X đấu Bot-X (luân phiên Rusher / Turtle / Poker)
##   0: Random · R/Enter: chơi lại phiên mới

const HUMAN_LOG_CSV := "data/raw/human_self.csv"
const WATCH_PAIRS := [
	{"label": "Mirror-Rusher vs Rusher", "model": "data/models/mirror_rusher.json", "bot": "rusher"},
	{"label": "Mirror-Turtle vs Turtle", "model": "data/models/mirror_turtle.json", "bot": "turtle"},
	{"label": "Mirror-Poker vs Poker", "model": "data/models/mirror_poker.json", "bot": "poker"},
]

@onready var _p1: FighterCharacter = $Fighter
@onready var _p2: FighterCharacter = $Opponent
@onready var _status: Label = $UI/Status
@onready var _hud: Node2D = $UI/Hud

var _match: FightMatch
var _opp_name: String = "Rusher"
var _logger: DataLogger = DataLogger.new()
var _human_session_seq: int = 0
var _watch_mode: bool = false
var _watch_idx: int = 0
var _flushed_current_match: bool = false


func _ready() -> void:
	_p2.body_color = Color(0.95, 0.45, 0.35, 1.0)
	_logger.open(HUMAN_LOG_CSV, true)
	_start_human_match("Rusher", BotRusher.new(randi()))
	if DisplayServer.get_name() == "headless":
		print("Mirror Duelist: headless session (main scene). Dùng headless_test.tscn / headless_matches.tscn.")


func _exit_tree() -> void:
	if _logger != null:
		_logger.close()


func _make_mirror_or_fallback(path: String) -> MirrorController:
	var ctrl := MirrorController.new(path, randi())
	if not ctrl.is_loaded() and path != MirrorController.DEFAULT_MODEL_PATH:
		ctrl.load_model(MirrorController.DEFAULT_MODEL_PATH)
	return ctrl


func _start_human_match(opp_label: String, opp_ctrl: Controller) -> void:
	_watch_mode = false
	_opp_name = opp_label
	_human_session_seq += 1
	_flushed_current_match = false
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


func _start_watch_match(pair_idx: int) -> void:
	_watch_mode = true
	var cfg: Dictionary = WATCH_PAIRS[pair_idx % WATCH_PAIRS.size()]
	_opp_name = str(cfg["label"])
	_flushed_current_match = false
	var ctrl_a := _make_mirror_or_fallback(str(cfg["model"]))
	var bot_name := str(cfg["bot"])
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


func _restart_current_mode() -> void:
	if _watch_mode:
		_start_watch_match(_watch_idx)
		return
	match _opp_name:
		"Turtle":
			_start_human_match("Turtle", BotTurtle.new(randi()))
		"Poker":
			_start_human_match("Poker", BotPoker.new(randi()))
		"Mirror":
			_start_human_match("Mirror", _make_mirror_or_fallback(MirrorController.DEFAULT_MODEL_PATH))
		"Mirror-Rusher":
			_start_human_match("Mirror-Rusher", _make_mirror_or_fallback("data/models/mirror_rusher.json"))
		"Mirror-Turtle":
			_start_human_match("Mirror-Turtle", _make_mirror_or_fallback("data/models/mirror_turtle.json"))
		"Mirror-Poker":
			_start_human_match("Mirror-Poker", _make_mirror_or_fallback("data/models/mirror_poker.json"))
		"Mirror-Self":
			_start_human_match("Mirror-Self", _make_mirror_or_fallback("data/models/mirror_human_self.json"))
		"Random":
			_start_human_match("Random", RandomController.new(randi()))
		_:
			_start_human_match("Rusher", BotRusher.new(randi()))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).physical_keycode
	if key == KEY_1:
		_start_human_match("Rusher", BotRusher.new(randi()))
	elif key == KEY_2:
		_start_human_match("Turtle", BotTurtle.new(randi()))
	elif key == KEY_3:
		_start_human_match("Poker", BotPoker.new(randi()))
	elif key == KEY_4:
		_start_human_match("Mirror", _make_mirror_or_fallback(MirrorController.DEFAULT_MODEL_PATH))
	elif key == KEY_5:
		_start_human_match("Mirror-Rusher", _make_mirror_or_fallback("data/models/mirror_rusher.json"))
	elif key == KEY_6:
		_start_human_match("Mirror-Turtle", _make_mirror_or_fallback("data/models/mirror_turtle.json"))
	elif key == KEY_7:
		_start_human_match("Mirror-Poker", _make_mirror_or_fallback("data/models/mirror_poker.json"))
	elif key == KEY_8:
		_start_human_match("Mirror-Self", _make_mirror_or_fallback("data/models/mirror_human_self.json"))
	elif key == KEY_9:
		if _watch_mode:
			_watch_idx = (_watch_idx + 1) % WATCH_PAIRS.size()
		_start_watch_match(_watch_idx)
	elif key == KEY_0:
		_start_human_match("Random", RandomController.new(randi()))


func _physics_process(_delta: float) -> void:
	if _match.finished:
		if not _flushed_current_match:
			if _logger != null:
				_logger.flush()
			_flushed_current_match = true
		if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_ENTER):
			_restart_current_mode()
		return
	_match.step()


func _process(_delta: float) -> void:
	var rows := _logger.rows_written if _logger != null else 0
	if _match.finished:
		var r := _match.result
		var text := "HOÀ"
		if int(r["winner"]) == 0:
			text = "P1 THẮNG" if _watch_mode else "BẠN THẮNG"
		elif int(r["winner"]) == 1:
			text = "P2 THẮNG" if _watch_mode else "BẠN THUA"
		_status.text = "%s | %s (%s) — R: phiên mới | Phiên: %d (%d mẫu) | 1..3:Bot 5..8:Mirror 9:Xem AI" % [
			text, _opp_name, "KO" if r["reason"] == "ko" else "hết giờ", _human_session_seq, rows
		]
	else:
		var secs := (GameConstants.ROUND_TIME_TICKS - _match.tick_count) / GameConstants.TARGET_FPS
		var prefix := "[XEM AI]" if _watch_mode else ("Đối thủ: %s" % _opp_name)
		_status.text = "%s | %ds | human_self: phiên %d (%d mẫu) | 1..3:Bot 5..8:Mirror 9:Xem Mirror-vs-Bot" % [
			prefix, secs, _human_session_seq, rows
		]
