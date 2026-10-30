extends Node2D
## Trận người vs AI. Phím 1: Rusher · 2: Turtle · 3: Poker · 4: Mirror · 0: Random · R/Enter: chơi lại.

@onready var _p1: FighterCharacter = $Fighter
@onready var _p2: FighterCharacter = $Opponent
@onready var _status: Label = $UI/Status
@onready var _hud: Node2D = $UI/Hud

var _match: FightMatch
var _opp_name: String = "Rusher"


func _ready() -> void:
	_p2.body_color = Color(0.95, 0.45, 0.35, 1.0)
	_start_match("Rusher", BotRusher.new(randi()))
	if DisplayServer.get_name() == "headless":
		print("Mirror Duelist: headless session (main scene). Dùng headless_test.tscn / headless_matches.tscn.")


func _start_match(opp_label: String, opp_ctrl: Controller) -> void:
	_opp_name = opp_label
	_match = FightMatch.new(_p1, _p2, HumanController.new(), opp_ctrl)
	_match.reset()
	_hud.fight = _match


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).physical_keycode
	if key == KEY_1:
		_start_match("Rusher", BotRusher.new(randi()))
	elif key == KEY_2:
		_start_match("Turtle", BotTurtle.new(randi()))
	elif key == KEY_3:
		_start_match("Poker", BotPoker.new(randi()))
	elif key == KEY_4:
		_start_match("Mirror", MirrorController.new(MirrorController.DEFAULT_MODEL_PATH, randi()))
	elif key == KEY_0:
		_start_match("Random", RandomController.new(randi()))


func _physics_process(_delta: float) -> void:
	if _match.finished:
		if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_ENTER):
			_match.reset()
		return
	_match.step()


func _process(_delta: float) -> void:
	if _match.finished:
		var r := _match.result
		var text := "HOÀ"
		if int(r["winner"]) == 0:
			text = "BẠN THẮNG"
		elif int(r["winner"]) == 1:
			text = "BẠN THUA"
		_status.text = "%s vs %s (%s) — nhấn R chơi lại | 1:Rusher 2:Turtle 3:Poker 4:Mirror" % [
			text, _opp_name, "KO" if r["reason"] == "ko" else "hết giờ"
		]
	else:
		var secs := (GameConstants.ROUND_TIME_TICKS - _match.tick_count) / GameConstants.TARGET_FPS
		_status.text = "Đối thủ: %s | Thời gian: %d (1:Rusher 2:Turtle 3:Poker 4:Mirror)" % [_opp_name, secs]
