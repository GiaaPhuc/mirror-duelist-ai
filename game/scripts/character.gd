class_name FighterCharacter
extends Node2D
## Tuần 2: nhân vật chiến đấu. Mô phỏng theo tick cố định (60 Hz), tất định,
## không dùng physics engine để chạy headless nhanh. Điều khiển qua apply_action()
## (được FightMatch gọi từ Controller.decide).

enum State { IDLE, ATTACK, BLOCK, STUN, DODGE, DASH }

const BODY_W := 28.0
const BODY_H := 56.0
const NEVER_HIT := 100000

@export var body_color: Color = Color(0.35, 0.55, 0.95, 1.0)

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
	for i in cooldowns.size():
		cooldowns[i] = 0


func _process(_delta: float) -> void:
	queue_redraw()


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
	velocity.x = push_dir * knockback
	intent = GameConstants.ACTION_IDLE
	attack_connected = true # huỷ đòn đang thực hiện, không gây sát thương thêm


func take_block(damage: float, push_dir: float) -> void:
	hp = maxf(hp - damage * GameConstants.BLOCK_DAMAGE_MULT, 0.0)
	velocity.x = push_dir * GameConstants.BLOCK_PUSHBACK


# --- Hiển thị (placeholder) ---

func _draw() -> void:
	var rect := Rect2(-BODY_W * 0.5, -BODY_H, BODY_W, BODY_H)
	var col := body_color
	if state == State.STUN:
		col = Color(1.0, 0.9, 0.3, 1.0)
	elif state == State.DODGE:
		col.a = 0.4 if is_invincible() else 0.7
	draw_rect(rect, col)
	draw_rect(rect, Color(0.1, 0.1, 0.15, 1.0), false, 2.0)
	if state == State.BLOCK:
		var sx := float(facing) * (BODY_W * 0.5 + 6.0)
		draw_line(Vector2(sx, -BODY_H + 4.0), Vector2(sx, -4.0), Color(0.5, 0.9, 1.0, 1.0), 5.0)
	var nose_x := float(facing) * (BODY_W * 0.5 + 4.0)
	draw_line(Vector2(nose_x - facing * 6.0, -BODY_H * 0.65), Vector2(nose_x, -BODY_H * 0.65), Color.WHITE, 3.0)
	if has_active_hitbox():
		var hb := get_hitbox()
		draw_rect(Rect2(hb.position - position, hb.size), Color(1.0, 0.3, 0.2, 0.55))
