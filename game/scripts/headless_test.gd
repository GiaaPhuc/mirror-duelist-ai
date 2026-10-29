extends Node
## Smoke test cho `godot --headless`: chạy 120 tick vật lý một trận ngẫu nhiên rồi thoát 0.

@onready var _fighter: FighterCharacter = $Fighter
@onready var _opponent: FighterCharacter = $Opponent

var _match: FightMatch
var _frames := 0
const FRAMES_TO_RUN := 120


func _ready() -> void:
	print("headless_test: starting")
	_match = FightMatch.new(_fighter, _opponent, RandomController.new(1), RandomController.new(2))
	_match.reset()


func _physics_process(_delta: float) -> void:
	_frames += 1
	_match.step()
	if _frames >= FRAMES_TO_RUN:
		print("HEADLESS_OK frames=%d pos=%s hp=%s/%s" % [_frames, _fighter.global_position, _fighter.hp, _opponent.hp])
		get_tree().quit(0)
