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
