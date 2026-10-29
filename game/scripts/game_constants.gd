extends Node
## Hằng số đồng bộ với SPEC.md (nguồn sự thật: SPEC + file này).

const N_ACTIONS := 10
const N_STATE := 22

const ACTION_IDLE := 0
const ACTION_WALK_FWD := 1
const ACTION_WALK_BACK := 2
const ACTION_JUMP := 3
const ACTION_LIGHT := 4
const ACTION_HEAVY := 5
const ACTION_KICK := 6
const ACTION_BLOCK := 7
const ACTION_DODGE := 8
const ACTION_DASH_FWD := 9

const ACTION_NAMES: PackedStringArray = [
	"idle", "walk_fwd", "walk_back", "jump", "light",
	"heavy", "kick", "block", "dodge", "dash_fwd",
]

const MAP_WIDTH := 960.0
const MAP_MAX_HEIGHT := 320.0
const MAX_RUN_SPEED := 240.0
const GRAVITY := 980.0
const JUMP_VELOCITY := -420.0
const TARGET_FPS := 60
const DECISION_INTERVAL_FRAMES := 6

## Góc dưới sàn arena (local Y); nhân vật đứng trên y = ARENA_FLOOR_Y - half_height
const ARENA_FLOOR_Y := 520.0
const ARENA_WALL_HALF := MAP_WIDTH * 0.5 + 32.0

# --- Tuần 2: luật chiến đấu (đơn vị: tick vật lý @ 60 Hz, px, px/s) ---
const MAX_HP := 100.0
const ROUND_TIME_TICKS := 3600 ## 60 giây
const START_X := 120.0 ## hai nhân vật bắt đầu tại ±START_X

const WALK_SPEED_FWD := 200.0
const WALK_SPEED_BACK := 150.0

## Frame data: startup -> active -> recovery. Hitbox là hình chữ nhật phía trước thân,
## y_top/y_bot tính từ chân nhân vật (âm = lên trên).
const MOVES: Dictionary = {
	ACTION_LIGHT: {
		"startup": 4, "active": 3, "recovery": 8,
		"damage": 5.0, "reach": 40.0, "y_top": -46.0, "y_bot": -18.0,
		"hitstun": 14, "knockback": 90.0,
	},
	ACTION_HEAVY: {
		"startup": 12, "active": 4, "recovery": 20,
		"damage": 14.0, "reach": 50.0, "y_top": -52.0, "y_bot": -14.0,
		"hitstun": 26, "knockback": 220.0,
	},
	ACTION_KICK: {
		"startup": 8, "active": 4, "recovery": 14,
		"damage": 9.0, "reach": 72.0, "y_top": -30.0, "y_bot": -2.0,
		"hitstun": 18, "knockback": 150.0,
	},
}

## Cooldown (tick) theo thứ tự state vector: heavy, kick, dash, dodge
const CD_HEAVY := 0
const CD_KICK := 1
const CD_DASH := 2
const CD_DODGE := 3
const COOLDOWN_TICKS: Array = [60, 40, 60, 90]

const BLOCK_DAMAGE_MULT := 0.2
const BLOCK_PUSHBACK := 120.0
const KNOCKBACK_DECAY_PER_TICK := 8.0

const DASH_TICKS := 12
const DASH_SPEED := 420.0

const DODGE_TICKS := 20
const DODGE_IFRAMES := 10 ## i-frames: tick 1..10 của dodge
const DODGE_MOVE_TICKS := 12
const DODGE_SPEED := 300.0
