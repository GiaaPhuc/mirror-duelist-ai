extends Node2D
## HUD: thanh HP hai bên (vẽ trong CanvasLayer nên theo toạ độ màn hình).

var fight: FightMatch = null

const BAR_W := 460.0
const BAR_H := 22.0
const BAR_Y := 52.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if fight == null:
		return
	var left_ratio := fight.fighters[0].hp / GameConstants.MAX_HP
	var right_ratio := fight.fighters[1].hp / GameConstants.MAX_HP
	var back := Color(0.15, 0.15, 0.18, 0.9)
	draw_rect(Rect2(40.0, BAR_Y, BAR_W, BAR_H), back)
	draw_rect(Rect2(40.0, BAR_Y, BAR_W * left_ratio, BAR_H), fight.fighters[0].body_color)
	draw_rect(Rect2(1240.0 - BAR_W, BAR_Y, BAR_W, BAR_H), back)
	draw_rect(Rect2(1240.0 - BAR_W * right_ratio, BAR_Y, BAR_W * right_ratio, BAR_H), fight.fighters[1].body_color)
