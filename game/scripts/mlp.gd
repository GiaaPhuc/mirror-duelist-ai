class_name MLP
extends RefCounted
## Forward pass mạng MLP (22 -> 64 -> 64 -> 10, ReLU ở lớp ẩn) thuần GDScript.
## Nạp trọng số và tham số chuẩn hoá (mean, std) từ file JSON xuất bởi PyTorch.

var layers: Array = []
var mean: PackedFloat32Array = PackedFloat32Array()
var std: PackedFloat32Array = PackedFloat32Array()


static func resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	if path.is_absolute_path():
		return path
	var game_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var repo_root := game_dir.get_base_dir()
	var candidate_repo := repo_root.path_join(path).simplify_path()
	if FileAccess.file_exists(candidate_repo):
		return candidate_repo
	var candidate_game := game_dir.path_join(path).simplify_path()
	if FileAccess.file_exists(candidate_game):
		return candidate_game
	return candidate_repo


func is_loaded() -> bool:
	return not layers.is_empty() and mean.size() == GameConstants.N_STATE and std.size() == GameConstants.N_STATE


func load_from_json(path: String) -> bool:
	var resolved := resolve_path(path)
	var f := FileAccess.open(resolved, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return false
	return load_from_dict(parsed)


func load_from_dict(data: Dictionary) -> bool:
	if not data.has("layers") or not data.has("mean") or not data.has("std"):
		return false
	var raw_mean: Array = data["mean"]
	var raw_std: Array = data["std"]
	if raw_mean.size() != GameConstants.N_STATE or raw_std.size() != GameConstants.N_STATE:
		return false

	mean.resize(raw_mean.size())
	std.resize(raw_std.size())
	for i in raw_mean.size():
		mean[i] = float(raw_mean[i])
		std[i] = maxf(float(raw_std[i]), 1e-8)

	layers = data["layers"]
	return not layers.is_empty()


func forward(state: PackedFloat32Array) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(state.size())
	for i in state.size():
		a[i] = (state[i] - mean[i]) / std[i]

	for li in layers.size():
		var W: Array = layers[li]["W"] # [out][in]
		var b: Array = layers[li]["b"]
		var out := PackedFloat32Array()
		out.resize(b.size())
		for o in b.size():
			var s: float = float(b[o])
			var row: Array = W[o]
			for j in a.size():
				s += float(row[j]) * a[j]
			out[o] = s
		if li < layers.size() - 1: # ReLU cho các lớp ẩn
			for o in out.size():
				out[o] = maxf(out[o], 0.0)
		a = out
	return a # logits


func argmax(logits: PackedFloat32Array) -> int:
	if logits.is_empty():
		return GameConstants.ACTION_IDLE
	var best_idx := 0
	var best_val := logits[0]
	for i in range(1, logits.size()):
		if logits[i] > best_val:
			best_val = logits[i]
			best_idx = i
	return best_idx


func probs(logits: PackedFloat32Array, temperature: float = 1.0) -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(logits.size())
	var m := -INF
	for v in logits:
		m = maxf(m, v)
	var temp := maxf(temperature, 0.01)
	var total := 0.0
	for i in logits.size():
		p[i] = exp((logits[i] - m) / temp)
		total += p[i]
	if total > 0.0:
		for i in p.size():
			p[i] /= total
	return p


func sample_action(logits: PackedFloat32Array, temperature: float = 0.7, rng: RandomNumberGenerator = null) -> int:
	if temperature <= 0.01:
		return argmax(logits)
	var p := probs(logits, temperature)
	var r := rng.randf() if rng != null else randf()
	var acc := 0.0
	for i in p.size():
		acc += p[i]
		if r <= acc:
			return i
	return p.size() - 1
