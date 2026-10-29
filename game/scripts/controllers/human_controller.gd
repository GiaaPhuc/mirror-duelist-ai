class_name HumanController
extends Controller
## Người chơi dùng bàn phím. Phím được đăng ký bằng code (không cần sửa project.godot).
## A/D hoặc ←/→ đi · W/Space nhảy · J đấm nhẹ · K đấm mạnh · L đá · S/↓ thủ (giữ) · Q né · E lao tới

const BINDINGS: Dictionary = {
	"act_light": [KEY_J],
	"act_heavy": [KEY_K],
	"act_kick": [KEY_L],
	"act_block": [KEY_S, KEY_DOWN],
	"act_dodge": [KEY_Q],
	"act_dash": [KEY_E],
}


func _init() -> void:
	every_frame = true
	for action in BINDINGS.keys():
		var action_name: String = action
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		for key in BINDINGS[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(key) as Key
			InputMap.action_add_event(action_name, ev)


func decide(_state: PackedFloat32Array) -> int:
	if Input.is_action_just_pressed("act_heavy"):
		return GameConstants.ACTION_HEAVY
	if Input.is_action_just_pressed("act_kick"):
		return GameConstants.ACTION_KICK
	if Input.is_action_just_pressed("act_light"):
		return GameConstants.ACTION_LIGHT
	if Input.is_action_just_pressed("act_dodge"):
		return GameConstants.ACTION_DODGE
	if Input.is_action_just_pressed("act_dash"):
		return GameConstants.ACTION_DASH_FWD
	if Input.is_action_just_pressed("jump"):
		return GameConstants.ACTION_JUMP
	if Input.is_action_pressed("act_block"):
		return GameConstants.ACTION_BLOCK
	var axis := Input.get_axis("move_left", "move_right")
	if axis != 0.0 and fighter != null:
		if (axis > 0.0) == (fighter.facing > 0):
			return GameConstants.ACTION_WALK_FWD
		return GameConstants.ACTION_WALK_BACK
	return GameConstants.ACTION_IDLE
