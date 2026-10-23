extends Node2D


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("Mirror Duelist: headless session (main scene). Dùng headless_test.tscn để smoke test tự thoát.")
