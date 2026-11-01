class_name FighterCharacter
extends Node2D
## Tuần 2: nhân vật chiến đấu. Mô phỏng theo tick cố định (60 Hz), tất định,
## không dùng physics engine để chạy headless nhanh. Điều khiển qua apply_action()
## (được FightMatch gọi từ Controller.decide).

enum State { IDLE, ATTACK, BLOCK, STUN, DODGE, DASH }

const BODY_W := 28.0
const BODY_H := 56.0
const NEVER_HIT := 100000
const SCARF_SEGMENTS := 6
const SCARF_SEG_LEN := 4.8

@export var body_color: Color = Color(0.22, 0.62, 0.98, 1.0)
@export var accent_color: Color = Color(0.25, 0.85, 1.0, 1.0)

var archetype: String = "player"
var is_mirror_clone: bool = false
var display_name: String = "NGƯỜI CHƠI"
var display_subtitle: String = "Võ Sĩ Ánh Sáng"
var show_debug_boxes: bool = false
var anim_time: float = 0.0
var hit_flash_ticks: int = 0
var scarf_points: PackedVector2Array = PackedVector2Array()

var facing: int = 1 ## 1 = nhìn phải, -1 = nhìn trái
var velocity := Vector2.ZERO
var hp: float = GameConstants.MAX_HP
var state: State = State.IDLE
var state_ticks: int = 0
var stun_left: int = 0
var intent: int = GameConstants.ACTION_IDLE ## hành động giữ liên tục (walk/block)
var current_action: int = GameConstants.ACTION_IDLE
var attack_connected: bool = false
var combo: int = 0
var ticks_since_hit: int = NEVER_HIT
var cooldowns: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

var _startup: int = 0
var _active: int = 0
var _total: int = 0
var _move: Dictionary = {}


func configure_visuals(
	role_key: String,
	mirror_flag: bool,
	title_text: String = "",
	subtitle_text: String = ""
) -> void:
	archetype = role_key.to_lower()
	is_mirror_clone = mirror_flag
	if title_text != "":
		display_name = title_text
	if subtitle_text != "":
		display_subtitle = subtitle_text

	if mirror_flag:
		body_color = Color(0.56, 0.44, 0.96, 1.0)
		accent_color = Color(0.45, 0.92, 1.0, 1.0)
		return

	match archetype:
		"player":
			body_color = Color(0.18, 0.56, 0.96, 1.0)
			accent_color = Color(0.22, 0.86, 1.0, 1.0)
		"rusher":
			body_color = Color(0.92, 0.28, 0.24, 1.0)
			accent_color = Color(1.0, 0.58, 0.18, 1.0)
		"turtle":
			body_color = Color(0.16, 0.72, 0.54, 1.0)
			accent_color = Color(0.38, 0.95, 0.72, 1.0)
		"poker":
			body_color = Color(0.76, 0.30, 0.88, 1.0)
			accent_color = Color(0.98, 0.46, 0.82, 1.0)
		_:
			body_color = Color(0.86, 0.66, 0.22, 1.0)
			accent_color = Color(1.0, 0.84, 0.32, 1.0)


func reset(x: float, face: int) -> void:
	position = Vector2(x, GameConstants.ARENA_FLOOR_Y)
	velocity = Vector2.ZERO
	facing = face
	hp = GameConstants.MAX_HP
	state = State.IDLE
	state_ticks = 0
	stun_left = 0
	intent = GameConstants.ACTION_IDLE
	current_action = GameConstants.ACTION_IDLE
	attack_connected = false
	combo = 0
	ticks_since_hit = NEVER_HIT
	hit_flash_ticks = 0
	for i in cooldowns.size():
		cooldowns[i] = 0
	_init_scarf()


func _init_scarf() -> void:
	scarf_points.resize(SCARF_SEGMENTS)
	var anchor := position + Vector2(-float(facing) * 3.0, -52.0)
	for i in SCARF_SEGMENTS:
		scarf_points[i] = anchor + Vector2(-float(facing) * float(i) * SCARF_SEG_LEN, float(i) * 1.2)


func _process(delta: float) -> void:
	anim_time += delta
	_update_scarf(delta)
	queue_redraw()


func _update_scarf(delta: float) -> void:
	if scarf_points.size() != SCARF_SEGMENTS:
		_init_scarf()
	var pose := FighterRenderer.compute_pose(self, anim_time)
	var head_local: Vector2 = pose["head"]
	var anchor := position + head_local + Vector2(-float(facing) * 3.5, -1.5)
	scarf_points[0] = anchor
	var wind_x := -float(facing) * 42.0 - velocity.x * 0.18 + sin(anim_time * 7.5) * 12.0
	var gravity_y := 26.0 + cos(anim_time * 6.0) * 8.0
	var step_dt := clampf(delta, 0.001, 0.05)
	for i in range(1, SCARF_SEGMENTS):
		var target_drift := Vector2(wind_x, gravity_y) * step_dt
		var cur := scarf_points[i] + target_drift
		var prev := scarf_points[i - 1]
		var diff := cur - prev
		var d := diff.length()
		if d > 0.001:
			scarf_points[i] = prev + (diff / d) * SCARF_SEG_LEN
		else:
			scarf_points[i] = prev + Vector2(-float(facing) * SCARF_SEG_LEN, 1.0)


# --- Truy vấn trạng thái ---

func is_on_floor() -> bool:
	return position.y >= GameConstants.ARENA_FLOOR_Y - 0.01 and velocity.y >= 0.0


## Actionable: không choáng, không giữa đòn/dash/dodge (dùng cho logger + nhận lệnh).
func is_actionable() -> bool:
	return state == State.IDLE or state == State.BLOCK


func is_invincible() -> bool:
	return state == State.DODGE and state_ticks <= GameConstants.DODGE_IFRAMES


func has_active_hitbox() -> bool:
	return state == State.ATTACK and state_ticks > _startup and state_ticks <= _startup + _active


func get_hurtbox() -> Rect2:
	return Rect2(position.x - BODY_W * 0.5, position.y - BODY_H, BODY_W, BODY_H)


func get_hitbox() -> Rect2:
	var reach: float = _move["reach"]
	var y_top: float = _move["y_top"]
	var y_bot: float = _move["y_bot"]
	var x0 := position.x + float(facing) * BODY_W * 0.5
	var x1 := x0 + float(facing) * reach
	return Rect2(minf(x0, x1), position.y + y_top, absf(x1 - x0), y_bot - y_top)


## 0 idle, 1 attacking (đòn/dash/dodge), 2 blocking, 3 stunned, 4 airborne.
func state_class() -> int:
	if state == State.STUN:
		return 3
	if state == State.ATTACK or state == State.DASH or state == State.DODGE:
		return 1
	if not is_on_floor():
		return 4
	if state == State.BLOCK:
		return 2
	return 0


func cooldown_ratio(index: int) -> float:
	return float(cooldowns[index]) / float(GameConstants.COOLDOWN_TICKS[index])


# --- Nhận lệnh ---

func apply_action(action: int) -> void:
	if not is_actionable():
		return
	var grounded := is_on_floor()
	if action == GameConstants.ACTION_JUMP:
		if grounded:
			velocity.y = GameConstants.JUMP_VELOCITY
		intent = GameConstants.ACTION_IDLE
	elif action == GameConstants.ACTION_LIGHT or action == GameConstants.ACTION_HEAVY \
			or action == GameConstants.ACTION_KICK:
		_start_attack(action)
	elif action == GameConstants.ACTION_DODGE:
		if grounded and cooldowns[GameConstants.CD_DODGE] == 0:
			cooldowns[GameConstants.CD_DODGE] = GameConstants.COOLDOWN_TICKS[GameConstants.CD_DODGE]
			_enter(State.DODGE, action)
		intent = GameConstants.ACTION_IDLE
	elif action == GameConstants.ACTION_DASH_FWD:
		if grounded and cooldowns[GameConstants.CD_DASH] == 0:
			cooldowns[GameConstants.CD_DASH] = GameConstants.COOLDOWN_TICKS[GameConstants.CD_DASH]
			_enter(State.DASH, action)
		intent = GameConstants.ACTION_IDLE
	else:
		intent = action # idle / walk_fwd / walk_back / block


func _start_attack(action: int) -> void:
	intent = GameConstants.ACTION_IDLE
	var cd_idx := -1
	if action == GameConstants.ACTION_HEAVY:
		cd_idx = GameConstants.CD_HEAVY
	elif action == GameConstants.ACTION_KICK:
		cd_idx = GameConstants.CD_KICK
	if cd_idx >= 0:
		if cooldowns[cd_idx] > 0:
			return
		cooldowns[cd_idx] = GameConstants.COOLDOWN_TICKS[cd_idx]
	_move = GameConstants.MOVES[action]
	_startup = _move["startup"]
	_active = _move["active"]
	_total = _startup + _active + int(_move["recovery"])
	attack_connected = false
	_enter(State.ATTACK, action)
	if is_on_floor():
		velocity.x = 0.0


func _enter(new_state: State, action: int) -> void:
	state = new_state
	state_ticks = 0
	current_action = action


# --- Mỗi tick ---

func face_opponent(opp: FighterCharacter) -> void:
	if state != State.IDLE and state != State.BLOCK:
		return
	var dx := opp.position.x - position.x
	if dx > 0.5:
		facing = 1
	elif dx < -0.5:
		facing = -1


func tick() -> void:
	if hit_flash_ticks > 0:
		hit_flash_ticks -= 1
	ticks_since_hit = mini(ticks_since_hit + 1, NEVER_HIT)
	for i in cooldowns.size():
		if cooldowns[i] > 0:
			cooldowns[i] -= 1

	if state == State.IDLE or state == State.BLOCK:
		_tick_free()
	elif state == State.ATTACK:
		_tick_attack()
	elif state == State.STUN:
		_tick_stun()
	elif state == State.DASH:
		_tick_dash()
	elif state == State.DODGE:
		_tick_dodge()
	_integrate()


func _tick_free() -> void:
	var grounded := is_on_floor()
	if intent == GameConstants.ACTION_BLOCK and grounded:
		state = State.BLOCK
	else:
		state = State.IDLE
	if not grounded:
		return # giữ quán tính khi trên không
	if state == State.BLOCK:
		velocity.x = 0.0
	elif intent == GameConstants.ACTION_WALK_FWD:
		velocity.x = float(facing) * GameConstants.WALK_SPEED_FWD
	elif intent == GameConstants.ACTION_WALK_BACK:
		velocity.x = -float(facing) * GameConstants.WALK_SPEED_BACK
	else:
		velocity.x = 0.0


func _tick_attack() -> void:
	state_ticks += 1
	if is_on_floor():
		velocity.x = 0.0
	if state_ticks > _total:
		state = State.IDLE
		state_ticks = 0


func _tick_stun() -> void:
	stun_left -= 1
	velocity.x = move_toward(velocity.x, 0.0, GameConstants.KNOCKBACK_DECAY_PER_TICK)
	if stun_left <= 0:
		state = State.IDLE
		state_ticks = 0
		velocity.x = 0.0


func _tick_dash() -> void:
	state_ticks += 1
	velocity.x = float(facing) * GameConstants.DASH_SPEED
	if state_ticks >= GameConstants.DASH_TICKS:
		state = State.IDLE
		state_ticks = 0
		velocity.x = 0.0


func _tick_dodge() -> void:
	state_ticks += 1
	if state_ticks <= GameConstants.DODGE_MOVE_TICKS:
		velocity.x = -float(facing) * GameConstants.DODGE_SPEED
	else:
		velocity.x = 0.0
	if state_ticks >= GameConstants.DODGE_TICKS:
		state = State.IDLE
		state_ticks = 0
		velocity.x = 0.0


func _integrate() -> void:
	var dt := 1.0 / float(GameConstants.TARGET_FPS)
	velocity.y += GameConstants.GRAVITY * dt
	position += velocity * dt
	if position.y >= GameConstants.ARENA_FLOOR_Y:
		position.y = GameConstants.ARENA_FLOOR_Y
		velocity.y = 0.0
	clamp_to_arena()


func clamp_to_arena() -> void:
	var half_w := BODY_W * 0.5
	position.x = clampf(position.x, -GameConstants.ARENA_WALL_HALF + half_w, GameConstants.ARENA_WALL_HALF - half_w)


# --- Nhận sát thương (do FightMatch gọi) ---

func take_hit(damage: float, hitstun: int, push_dir: float, knockback: float) -> void:
	hp = maxf(hp - damage, 0.0)
	state = State.STUN
	state_ticks = 0
	stun_left = hitstun
	hit_flash_ticks = 4
	velocity.x = push_dir * knockback
	intent = GameConstants.ACTION_IDLE
	attack_connected = true # huỷ đòn đang thực hiện, không gây sát thương thêm


func take_block(damage: float, push_dir: float) -> void:
	hp = maxf(hp - damage * GameConstants.BLOCK_DAMAGE_MULT, 0.0)
	velocity.x = push_dir * GameConstants.BLOCK_PUSHBACK


# --- Hiển thị Võ sĩ Stylized Shadow-Neon ---

func _draw() -> void:
	FighterRenderer.draw_fighter(self, self, anim_time, 1.0)
