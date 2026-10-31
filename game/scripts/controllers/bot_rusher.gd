class_name BotRusher
extends Controller
## Bot nguyên mẫu 1 — Rusher: luôn tiến lên áp sát, ưu tiên `light` + `dash_fwd`,
## dùng `heavy` khi đối thủ choáng/thủ hoặc nối combo để dứt điểm, rất ít thủ.
## Có xác suất `epsilon` (mặc định 12%) chọn hành động ngẫu nhiên để dữ liệu đa dạng.

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


## Luật quyết định thuần theo state 22 chiều (dùng được cho cả DAgger query ở Tuần 8).
func decide_rule(state: PackedFloat32Array) -> int:
	var dist_px := absf(state[0]) * GameConstants.MAP_WIDTH
	var cd_heavy := state[4]
	var cd_kick := state[5]
	var cd_dash := state[6]
	var opp_attacking := state[14] > 0.5
	var opp_blocking := state[15] > 0.5
	var opp_stunned := state[16] > 0.5
	var my_combo := state[20]
	var recent_hit := state[21]

	# Tầm xa / trung-xa: lao tới bằng dash_fwd nếu hồi chiêu, không thì đi bộ tiến lên
	if dist_px > 92.0:
		if cd_dash <= 0.001 and dist_px <= 280.0:
			return GameConstants.ACTION_DASH_FWD
		return GameConstants.ACTION_WALK_FWD

	# Tầm nhỡ (ngoài tầm light 68px nhưng trong tầm áp sát): dash hoặc kick hoặc tiến tiếp
	if dist_px > 66.0:
		if cd_dash <= 0.001:
			return GameConstants.ACTION_DASH_FWD
		if cd_kick <= 0.001 and dist_px >= 76.0:
			return GameConstants.ACTION_KICK
		return GameConstants.ACTION_WALK_FWD

	# Tầm cận chiến (<= 66px): ưu tiên đấm nhẹ liên hoàn, xen heavy khi đối thủ hở/thủ hoặc nối combo
	if (opp_stunned or opp_blocking or my_combo >= 0.2) and cd_heavy <= 0.001:
		return GameConstants.ACTION_HEAVY
	if opp_attacking and recent_hit < 0.08:
		return GameConstants.ACTION_BLOCK
	return GameConstants.ACTION_LIGHT
