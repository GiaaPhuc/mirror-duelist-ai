extends Node2D
## Trận người vs bot ngẫu nhiên. Nhấn R (hoặc Enter) để chơi lại sau khi hết trận.

@onready var _p1: FighterCharacter = $Fighter
@onready var _p2: FighterCharacter = $Opponent
@onready var _status: Label = $UI/Status
@onready var _hud: Node2D = $UI/Hud

var _match: FightMatch


func _ready() -> void:
	_p2.body_color = Color(0.95, 0.45, 0.35, 1.0)
	_match = FightMatch.new(_p1, _p2, HumanController.new(), RandomController.new(randi()))
	_match.reset()
	_hud.fight = _match
	if DisplayServer.get_name() == "headless":
		print("Mirror Duelist: headless session (main scene). Dùng headless_test.tscn / headless_matches.tscn.")


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
		_status.text = "%s (%s) — nhấn R để chơi lại" % [text, "KO" if r["reason"] == "ko" else "hết giờ"]
	else:
		var secs := (GameConstants.ROUND_TIME_TICKS - _match.tick_count) / GameConstants.TARGET_FPS
		_status.text = "Thời gian: %d" % secs
