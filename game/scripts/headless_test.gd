extends Node
## Smoke test cho `godot --headless`: chạy vài frame vật lý rồi thoát 0.

@onready var _fighter: FighterCharacter = $Fighter

var _frames := 0
const FRAMES_TO_RUN := 120


func _ready() -> void:
	print("headless_test: starting")


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 30:
		_fighter.velocity.x = GameConstants.MAX_RUN_SPEED
	if _frames == 60 and _fighter.is_on_floor():
		_fighter.velocity.y = GameConstants.JUMP_VELOCITY

	if _frames >= FRAMES_TO_RUN:
		print("HEADLESS_OK frames=%d pos=%s vel=%s" % [_frames, _fighter.global_position, _fighter.velocity])
		get_tree().quit(0)
