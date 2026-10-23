extends Node2D
## Arena phẳng: sàn + tường hai bên (placeholder hình chữ nhật).

const FLOOR_THICKNESS := 24.0
const WALL_THICKNESS := 32.0
const FLOOR_COLOR := Color(0.22, 0.24, 0.28, 1.0)
const WALL_COLOR := Color(0.45, 0.32, 0.28, 1.0)
const SKY_COLOR := Color(0.12, 0.14, 0.2, 1.0)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var half_w := GameConstants.ARENA_WALL_HALF
	var floor_y := GameConstants.ARENA_FLOOR_Y
	var top_y := floor_y - GameConstants.MAP_MAX_HEIGHT - 40.0

	# Nền
	draw_rect(Rect2(-half_w - 80.0, top_y - 40.0, half_w * 2.0 + 160.0, floor_y - top_y + 120.0), SKY_COLOR)

	# Sàn
	draw_rect(Rect2(-half_w - WALL_THICKNESS, floor_y, half_w * 2.0 + WALL_THICKNESS * 2.0, FLOOR_THICKNESS), FLOOR_COLOR)

	# Tường trái / phải
	var wall_h := floor_y - top_y + FLOOR_THICKNESS
	draw_rect(Rect2(-half_w - WALL_THICKNESS, top_y, WALL_THICKNESS, wall_h), WALL_COLOR)
	draw_rect(Rect2(half_w, top_y, WALL_THICKNESS, wall_h), WALL_COLOR)

	# Vạch giữa sân
	draw_line(Vector2(0.0, top_y), Vector2(0.0, floor_y), Color(1, 1, 1, 0.08), 2.0)
