class_name Controller
extends RefCounted
## Interface chung: người chơi, bot và model đều cắm vào đây.
## `decide(state)` nhận state vector 22 chiều (đã mirror hoá) và trả về action_id (0..9).

## Nhân vật mà controller đang điều khiển (FightMatch gán). Chỉ dùng cho input người chơi.
var fighter: FighterCharacter = null

## true: được hỏi mỗi tick (người chơi). false: chỉ hỏi ở 10 Hz (bot/model).
var every_frame: bool = false


func decide(_state: PackedFloat32Array) -> int:
	return GameConstants.ACTION_IDLE
