class_name MirrorController
extends Controller
## Controller chạy mạng MLP học từ dữ liệu hành vi (Behavior Cloning).
## Nạp trọng số từ file JSON (mặc định `data/models/mirror.json`).

const DEFAULT_MODEL_PATH := "data/models/mirror.json"

var mlp := MLP.new()
var temperature: float = 0.7
var greedy: bool = false
var rng := RandomNumberGenerator.new()
var model_path: String = DEFAULT_MODEL_PATH
var last_probs: PackedFloat32Array = PackedFloat32Array()
var last_action: int = GameConstants.ACTION_IDLE


func _init(
	path: String = DEFAULT_MODEL_PATH,
	seed_value: int = 0,
	temp: float = 0.7,
	use_greedy: bool = false
) -> void:
	every_frame = false
	model_path = path if path != "" else DEFAULT_MODEL_PATH
	temperature = temp
	greedy = use_greedy
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	mlp.load_from_json(model_path)


func load_model(path: String) -> bool:
	model_path = path
	return mlp.load_from_json(path)


func is_loaded() -> bool:
	return mlp.is_loaded()


func decide(state: PackedFloat32Array) -> int:
	if not mlp.is_loaded():
		last_action = GameConstants.ACTION_IDLE
		return last_action
	var logits := mlp.forward(state)
	last_probs = mlp.probs(logits, temperature)
	if greedy:
		last_action = mlp.argmax(logits)
		return last_action
	last_action = mlp.sample_action(logits, temperature, rng)
	return last_action
