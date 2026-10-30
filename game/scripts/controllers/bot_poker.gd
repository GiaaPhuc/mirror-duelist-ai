class_name BotPoker
extends Controller
## Bot nguyên mẫu 3 — Poker: giữ khoảng cách trung bình (~75–105 px),
## dùng `kick` (tầm xa 72 px) để rỉa máu rồi lùi (`walk_back`), và `dodge` ngay khi bị áp sát.
## Có xác suất `epsilon` (mặc định 12%) chọn hành động ngẫu nhiên.

var rng := RandomNumberGenerator.new()
var epsilon: float = 0.12


func _init(seed_value: int = 0, epsilon_value: float = 0.12) -> void:
	every_frame = false
	epsilon = clampf(epsilon_value, 0.0, 1.0)
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func decide(state: PackedFloat32Array) -> int:
	if epsilon > 0.0 and rng.randf() < epsilon:
		return rng.randi_range(0, GameConstants.N_ACTIONS - 1)
	return decide_rule(state)


## Luật quyết định thuần theo state 22 chiều (hỗ trợ cả DAgger query ở Tuần 8).
func decide_rule(state: PackedFloat32Array) -> int:
	var dist_px := absf(state[0]) * GameConstants.MAP_WIDTH
	var cd_kick := state[5]
	var cd_dodge := state[7]
	var opp_attacking := state[14] > 0.5

	# 1. Bị áp sát (< 72px): ưu tiên dodge lùi thoát thân, nếu đang hồi thì lùi hoặc thủ/light
	if dist_px < 72.0:
		if cd_dodge <= 0.001 and rng.randf() < 0.80:
			return GameConstants.ACTION_DODGE
		if opp_attacking and rng.randf() < 0.55:
			return GameConstants.ACTION_BLOCK
		if rng.randf() < 0.65:
			return GameConstants.ACTION_WALK_BACK
		return GameConstants.ACTION_LIGHT

	# 2. Tầm rỉa đòn lý tưởng của kick (72..102px — ngoài tầm light của đối thủ):
	#    Nếu kick sẵn sàng thì đá, nếu vừa đá xong (cd_kick > 0) thì lùi ngay.
	if dist_px <= 102.0:
		if cd_kick <= 0.001:
			if rng.randf() < 0.82:
				return GameConstants.ACTION_KICK
			return GameConstants.ACTION_WALK_BACK
		# Đang hồi chiêu kick -> rút lùi giữ khoảng cách
		if rng.randf() < 0.78:
			return GameConstants.ACTION_WALK_BACK
		return GameConstants.ACTION_BLOCK if opp_attacking else GameConstants.ACTION_IDLE

	# 3. Hơi xa hơn tầm kick (102..145px): nếu vừa đá xong thì lùi/chờ, nếu kick sẵn sàng thì bước vào
	if dist_px <= 145.0:
		if cd_kick > 0.25:
			if rng.randf() < 0.60:
				return GameConstants.ACTION_WALK_BACK
			return GameConstants.ACTION_IDLE
		if rng.randf() < 0.78:
			return GameConstants.ACTION_WALK_FWD
		return GameConstants.ACTION_IDLE

	# 4. Quá xa (> 145px): tiến vào khoảng cách trung bình
	if rng.randf() < 0.85:
		return GameConstants.ACTION_WALK_FWD
	return GameConstants.ACTION_IDLE
