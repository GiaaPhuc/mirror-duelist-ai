class_name DataLogger
extends RefCounted
## Ghi quyết định (state 22 chiều + action) ra file CSV ở tần suất 10 Hz,
## chỉ ghi khi nhân vật đang actionable (theo đúng SPEC.md mục CSV).

var file_path: String = ""
var rows_written: int = 0
var _file: FileAccess = null


static func resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	var game_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	if path.begins_with("../") or path.begins_with("..\\"):
		return game_dir.path_join(path).simplify_path()
	var repo_root := game_dir.get_base_dir()
	return repo_root.path_join(path).simplify_path()


static func header_line() -> String:
	var cols := PackedStringArray(["session_id", "player_id", "tick"])
	for i in GameConstants.N_STATE:
		cols.append("s%d" % i)
	cols.append("action")
	return ",".join(cols)


func open(path: String, append: bool = false) -> bool:
	close()
	file_path = resolve_path(path)
	var base_dir := file_path.get_base_dir()
	if base_dir != "":
		DirAccess.make_dir_recursive_absolute(base_dir)

	var exists := FileAccess.file_exists(file_path)
	if append and exists:
		_file = FileAccess.open(file_path, FileAccess.READ_WRITE)
		if _file == null:
			return false
		_file.seek_end()
		if _file.get_position() == 0:
			_file.store_line(header_line())
	else:
		_file = FileAccess.open(file_path, FileAccess.WRITE)
		if _file == null:
			return false
		_file.store_line(header_line())
	return true


func is_open() -> bool:
	return _file != null


## Ghi 1 dòng nếu đúng tick quyết định 10 Hz và nhân vật đang actionable.
func log_decision(
	session_id: String,
	player_id: String,
	tick: int,
	 state: PackedFloat32Array,
	action: int,
	actionable: bool = true
) -> bool:
	if _file == null:
		return false
	if not actionable:
		return false
	if tick % GameConstants.DECISION_INTERVAL_FRAMES != 0:
		return false
	if state.size() != GameConstants.N_STATE:
		return false
	if action < 0 or action >= GameConstants.N_ACTIONS:
		return false

	var parts := PackedStringArray([session_id, player_id, str(tick)])
	for i in GameConstants.N_STATE:
		parts.append("%.6f" % state[i])
	parts.append(str(action))
	_file.store_line(",".join(parts))
	rows_written += 1
	return true


func flush() -> void:
	if _file != null:
		_file.flush()


func close() -> void:
	if _file != null:
		_file.flush()
		_file = null
