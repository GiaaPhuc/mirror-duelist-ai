class_name BotTurtle
extends Controller
## Bot nguyên mẫu 2 — Turtle: giữ khoảng cách xa, ưu tiên `block` và `walk_back`,
## chỉ phản công (punish) khi đối thủ đánh hụt ở tầm trung-gần, bị choáng, hoặc vừa chạm khiên.
## Có xác suất `epsilon` (mặc định 12%) chọn hành động ngẫu nhiên.

var rng := RandomNumberGenerator.new()
var epsilon: float = 0.12
var _opp_was_attacking: bool = false


func _init(seed_value: int = 0, epsilon_value: float = 0.12) -> void:
	every_frame = false
	epsilon = clampf(epsilon_value, 0.0, 1.0)
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func decide(state: PackedFloat32Array) -> int:
	if epsilon > 0.0 and rng.randf() < epsilon:
		_opp_was_attacking = state[14] > 0.5
		return rng.randi_range(0, GameConstants.N_ACTIONS - 1)
	return decide_rule(state)


## Luật quyết định thuần theo state 22 chiều (hỗ trợ cả DAgger query ở Tuần 8).
func decide_rule(state: PackedFloat32Array) -> int:
	var dist_px := absf(state[0]) * GameConstants.MAP_WIDTH
	var cd_heavy := state[4]
	var cd_kick := state[5]
	var cd_dodge := state[7]
	var me_blocking := state[10] > 0.5
	var opp_attacking := state[14] > 0.5
	var opp_stunned := state[16] > 0.5
	var opp_vel := state[19]
	var recent_hit_norm := state[21]

	var opp_just_whiffed := _opp_was_attacking and not opp_attacking and recent_hit_norm > 0.15
	var just_blocked_hit := me_blocking and recent_hit_norm < 0.12 and not opp_attacking
	_opp_was_attacking = opp_attacking

	# 1. Cơ hội phản công rõ ràng: đối thủ bị choáng, vừa đánh hụt, hoặc vừa bị đỡ đòn
	if dist_px <= 98.0 and (opp_stunned or opp_just_whiffed or just_blocked_hit):
		if dist_px <= 76.0 and cd_heavy <= 0.001:
			return GameConstants.ACTION_HEAVY
		if dist_px <= 98.0 and cd_kick <= 0.001:
			return GameConstants.ACTION_KICK
		if dist_px <= 66.0:
			return GameConstants.ACTION_LIGHT

	# 2. Đối thủ đang tung đòn ở ngoài tầm light (đánh hụt trước mặt): trả đòn bằng kick/heavy
	if opp_attacking and dist_px > 68.0 and dist_px <= 98.0:
		if cd_kick <= 0.001 and rng.randf() < 0.70:
			return GameConstants.ACTION_KICK
		return GameConstants.ACTION_BLOCK

	# 3. Đối thủ đang tung đòn hoặc lao vào ở tầm gần: dựng khiên thủ
	if (opp_attacking or opp_vel < -0.25) and dist_px <= 135.0:
		return GameConstants.ACTION_BLOCK

	# 4. Bị áp sát quá gần (<= 74px): ưu tiên block hoặc dodge lùi, thỉnh thoảng đấm nhẹ đẩy ra
	if dist_px <= 74.0:
		var r := rng.randf()
		if r < 0.65:
			return GameConstants.ACTION_BLOCK
		if r < 0.85 and cd_dodge <= 0.001:
			return GameConstants.ACTION_DODGE
		return GameConstants.ACTION_LIGHT

	# 5. Khoảng cách trung bình (74..175px): lùi để kéo giãn khoảng cách hoặc thủ
	if dist_px < 175.0:
		if rng.randf() < 0.65:
			return GameConstants.ACTION_WALK_BACK
		return GameConstants.ACTION_BLOCK

	# 6. Đã ở khoảng cách xa (>= 175px): giữ vị trí, thủ chờ đối phương tiến vào
	if dist_px > 260.0 and rng.randf() < 0.25:
		return GameConstants.ACTION_WALK_FWD
	if rng.randf() < 0.60:
		return GameConstants.ACTION_BLOCK
	return GameConstants.ACTION_IDLE
