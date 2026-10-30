class_name FightMatch
extends RefCounted
## Một trận đấu 1v1: điều phối controller → nhân vật → va chạm → kết thúc trận.
## Không phụ thuộc scene, step() chạy được trong vòng lặp headless với tốc độ tối đa.

var fighters: Array[FighterCharacter] = []
var controllers: Array[Controller] = []
var tick_count: int = 0
var finished: bool = false
## Khi finished: {winner: 0|1|-1(hoà), hp_a, hp_b, ticks, reason: "ko"|"timeout"}
var result: Dictionary = {}

## Tuần 3: cấu hình ghi dữ liệu quyết định (10 Hz, chỉ khi actionable).
var logger: DataLogger = null
var session_id: String = "s0"
var player_ids: Array[String] = ["p1", "p2"]
var log_fighters: Array[bool] = [false, false]


func _init(a: FighterCharacter, b: FighterCharacter, ctrl_a: Controller, ctrl_b: Controller) -> void:
	fighters.append(a)
	fighters.append(b)
	controllers.append(ctrl_a)
	controllers.append(ctrl_b)
	ctrl_a.fighter = a
	ctrl_b.fighter = b


func configure_logging(
	data_logger: DataLogger,
	sid: String,
	p1_id: String = "p1",
	p2_id: String = "p2",
	log_p1: bool = true,
	log_p2: bool = false
) -> void:
	logger = data_logger
	session_id = sid
	player_ids = [p1_id, p2_id]
	log_fighters = [log_p1, log_p2]


func reset() -> void:
	fighters[0].reset(-GameConstants.START_X, 1)
	fighters[1].reset(GameConstants.START_X, -1)
	tick_count = 0
	finished = false
	result = {}


func step() -> void:
	if finished:
		return

	# 1. Quyết định (cả hai nhìn state cùng một thời điểm, tránh lệch thứ tự)
	var is_log_tick := (tick_count % GameConstants.DECISION_INTERVAL_FRAMES == 0)
	var decide_now: Array[bool] = [false, false]
	var actionable: Array[bool] = [false, false]
	var states: Array[PackedFloat32Array] = []
	for i in 2:
		states.append(StateEncoder.encode(fighters[i], fighters[1 - i]))
		actionable[i] = fighters[i].is_actionable()
		decide_now[i] = actionable[i] and (controllers[i].every_frame or is_log_tick)
	for i in 2:
		if decide_now[i]:
			var act := controllers[i].decide(states[i])
			if logger != null and log_fighters[i] and is_log_tick:
				logger.log_decision(session_id, player_ids[i], tick_count, states[i], act, actionable[i])
			fighters[i].apply_action(act)

	# 2. Cập nhật nhân vật
	fighters[0].face_opponent(fighters[1])
	fighters[1].face_opponent(fighters[0])
	fighters[0].tick()
	fighters[1].tick()

	# 3. Va chạm đòn đánh, đẩy nhau, combo
	_resolve_hits()
	_separate()
	for i in 2:
		if fighters[1 - i].state != FighterCharacter.State.STUN:
			fighters[i].combo = 0

	# 4. Kết thúc trận
	tick_count += 1
	_check_end()


func _resolve_hits() -> void:
	# Pha 1: xác định mọi cú trúng dựa trên trạng thái trước khi áp dụng (đối xứng, không phụ thuộc thứ tự).
	var hits: Array[Dictionary] = []
	for i in 2:
		var atk := fighters[i]
		var def := fighters[1 - i]
		if not atk.has_active_hitbox() or atk.attack_connected:
			continue
		if def.is_invincible():
			continue
		if not atk.get_hitbox().intersects(def.get_hurtbox()):
			continue
		var in_front := (atk.position.x - def.position.x) * float(def.facing) > 0.0
		hits.append({
			"atk": atk,
			"def": def,
			"blocked": def.state == FighterCharacter.State.BLOCK and in_front,
			"was_stunned": def.state == FighterCharacter.State.STUN,
		})
	# Pha 2: áp dụng.
	for h in hits:
		var atk: FighterCharacter = h["atk"]
		var def: FighterCharacter = h["def"]
		var move: Dictionary = GameConstants.MOVES[atk.current_action]
		var push_dir := 1.0 if def.position.x >= atk.position.x else -1.0
		atk.attack_connected = true
		atk.ticks_since_hit = 0
		def.ticks_since_hit = 0
		if h["blocked"]:
			def.take_block(move["damage"], push_dir)
		else:
			atk.combo = atk.combo + 1 if h["was_stunned"] else 1
			def.take_hit(move["damage"], move["hitstun"], push_dir, move["knockback"])
			atk.attack_connected = true


func _separate() -> void:
	var a := fighters[0]
	var b := fighters[1]
	if absf(a.position.y - b.position.y) >= FighterCharacter.BODY_H:
		return
	var dx := b.position.x - a.position.x
	var overlap := FighterCharacter.BODY_W - absf(dx)
	if overlap <= 0.0:
		return
	var dir := 1.0
	if dx < 0.0 or (dx == 0.0 and a.facing < 0):
		dir = -1.0
	a.position.x -= dir * overlap * 0.5
	b.position.x += dir * overlap * 0.5
	a.clamp_to_arena()
	b.clamp_to_arena()
	var rem := FighterCharacter.BODY_W - absf(b.position.x - a.position.x)
	if rem > 0.0:
		b.position.x += dir * rem
		b.clamp_to_arena()
		rem = FighterCharacter.BODY_W - absf(b.position.x - a.position.x)
		if rem > 0.0:
			a.position.x -= dir * rem
			a.clamp_to_arena()


func _check_end() -> void:
	var hp_a := fighters[0].hp
	var hp_b := fighters[1].hp
	var reason := ""
	if hp_a <= 0.0 or hp_b <= 0.0:
		reason = "ko"
	elif tick_count >= GameConstants.ROUND_TIME_TICKS:
		reason = "timeout"
	if reason == "":
		return
	var winner := -1
	if hp_a > hp_b:
		winner = 0
	elif hp_b > hp_a:
		winner = 1
	finished = true
	result = {"winner": winner, "hp_a": hp_a, "hp_b": hp_b, "ticks": tick_count, "reason": reason}
