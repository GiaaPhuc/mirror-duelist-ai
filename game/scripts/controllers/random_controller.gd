class_name RandomController
extends Controller
## Controller giả: chọn ngẫu nhiên đều 10 hành động (seed cố định để lặp lại được).

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value


func decide(_state: PackedFloat32Array) -> int:
	return rng.randi_range(0, GameConstants.N_ACTIONS - 1)
