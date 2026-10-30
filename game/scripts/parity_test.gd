extends Node
## Kiểm tra độ khớp số học giữa forward pass GDScript (`MLP`) và PyTorch trên `test_vectors.json`,
## đồng thời chạy thử 1 trận `MirrorController` vs `BotRusher` để xác nhận tích hợp.
## Yêu cầu: sai số tuyệt đối lớn nhất (max_abs_err) < 1e-4.

const DEFAULT_MODEL := "data/models/mirror.json"
const DEFAULT_VECTORS := "data/models/test_vectors.json"
const TOLERANCE := 1e-4


func _ready() -> void:
	var model_path := DEFAULT_MODEL
	var vectors_path := DEFAULT_VECTORS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model_path = arg.substr(8).strip_edges()
		elif arg.begins_with("--vectors="):
			vectors_path = arg.substr(10).strip_edges()
	var code := run_parity_check(model_path, vectors_path)
	get_tree().quit(code)


func run_parity_check(model_path: String, vectors_path: String) -> int:
	var mlp := MLP.new()
	if not mlp.load_from_json(model_path):
		printerr("PARITY_FAIL: không nạp được model JSON: " + model_path)
		return 1

	var resolved_vec := MLP.resolve_path(vectors_path)
	var f := FileAccess.open(resolved_vec, FileAccess.READ)
	if f == null:
		printerr("PARITY_FAIL: không mở được test_vectors.json: " + vectors_path)
		return 1
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("vectors"):
		printerr("PARITY_FAIL: định dạng test_vectors.json không hợp lệ")
		return 1

	var vectors: Array = parsed["vectors"]
	if vectors.is_empty():
		printerr("PARITY_FAIL: danh sách test vectors rỗng")
		return 1

	var max_err := 0.0
	for idx in vectors.size():
		var item: Dictionary = vectors[idx]
		var raw_s: Array = item["state"]
		var expected_logits: Array = item["logits"]
		var s := PackedFloat32Array()
		s.resize(raw_s.size())
		for i in raw_s.size():
			s[i] = float(raw_s[i])

		var got_logits := mlp.forward(s)
		if got_logits.size() != expected_logits.size():
			printerr("PARITY_FAIL: vector %d sai kích thước logits (%d vs %d)" % [
				idx, got_logits.size(), expected_logits.size()
			])
			return 1
		for j in got_logits.size():
			var err := absf(got_logits[j] - float(expected_logits[j]))
			max_err = maxf(max_err, err)

	print("PARITY_CHECK vectors=%d max_abs_err=%.8f tolerance=%.6f" % [
		vectors.size(), max_err, TOLERANCE
	])
	if max_err >= TOLERANCE or is_nan(max_err):
		printerr("PARITY_FAIL: max_abs_err %.8f >= %.6f" % [max_err, TOLERANCE])
		return 1

	# Smoke test chạy 1 trận MirrorController vs BotRusher
	var a := FighterCharacter.new()
	var b := FighterCharacter.new()
	var mirror_ctrl := MirrorController.new(model_path, 42, 0.7)
	var bot_ctrl := BotRusher.new(43, 0.12)
	var m := FightMatch.new(a, b, mirror_ctrl, bot_ctrl)
	m.reset()
	while not m.finished:
		m.step()
	var r := m.result
	a.free()
	b.free()
	print("PARITY_MATCH_OK winner=%d ticks=%d hp=%.1f/%.1f" % [
		int(r["winner"]), int(r["ticks"]), float(r["hp_a"]), float(r["hp_b"])
	])
	print("PARITY_OK")
	return 0
