class_name FighterCharacter
extends CharacterBody2D
## Tuần 1: di chuyển ngang, nhảy, trọng lực. Tuần 2+: chiến đấu qua Controller.

@export var run_speed: float = GameConstants.MAX_RUN_SPEED
@export var jump_velocity: float = GameConstants.JUMP_VELOCITY
@export var body_color: Color = Color(0.35, 0.55, 0.95, 1.0)
@export var keyboard_control_enabled: bool = true

const BODY_W := 28.0
const BODY_H := 56.0

var facing: int = 1 ## 1 = nhìn phải, -1 = nhìn trái

func _ready() -> void:
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * _delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	if keyboard_control_enabled:
		_apply_keyboard_input()
	else:
		velocity.x = move_toward(velocity.x, 0.0, run_speed * 4.0 * _delta)

	move_and_slide()
	_clamp_to_arena()
	queue_redraw()


func _apply_keyboard_input() -> void:
	var axis := Input.get_axis("move_left", "move_right")
	velocity.x = axis * run_speed
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


func _clamp_to_arena() -> void:
	var half_w := BODY_W * 0.5
	var min_x := -GameConstants.ARENA_WALL_HALF + half_w
	var max_x := GameConstants.ARENA_WALL_HALF - half_w
	global_position.x = clampf(global_position.x, min_x, max_x)


func _draw() -> void:
	var rect := Rect2(-BODY_W * 0.5, -BODY_H, BODY_W, BODY_H)
	draw_rect(rect, body_color)
	draw_rect(rect, Color(0.1, 0.1, 0.15, 1.0), false, 2.0)
	# Mũi hướng nhìn
	var nose_x := float(facing) * (BODY_W * 0.5 + 4.0)
	draw_line(Vector2(nose_x - facing * 6.0, -BODY_H * 0.65), Vector2(nose_x, -BODY_H * 0.65), Color.WHITE, 3.0)
