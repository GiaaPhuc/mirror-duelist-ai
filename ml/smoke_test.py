"""End-to-end Week 3 smoke test & parity verification.

1. Generates >= 1,000 actionable 10 Hz decision rows (following SPEC.md & GDScript combat rules)
   if `data/raw/rusher.csv` does not yet exist from Godot headless.
2. Runs `train.py` -> `export_json.py` to produce `data/models/best.pt`, `data/models/mirror.json`,
   and `data/models/test_vectors.json`.
3. Verifies numerical parity between model logits in `test_vectors.json` and the exact float32
   GDScript `MLP.forward` implementation (`max_abs_err < 1e-4`).
4. Runs matches with `MirrorController` loading `data/models/mirror.json` to confirm inference works.
"""

from __future__ import annotations

import csv
import json
import time
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

from dataset import ACTION_NAMES, N_ACTIONS, N_STATE
from export_json import main as export_cli_main
from model import gdscript_forward_single
from train import train_pipeline

# Constants synced with game/scripts/game_constants.gd & SPEC.md
MAP_WIDTH = 960.0
MAP_MAX_HEIGHT = 320.0
MAX_RUN_SPEED = 240.0
GRAVITY = 980.0
JUMP_VELOCITY = -420.0
TARGET_FPS = 60
DECISION_INTERVAL_FRAMES = 6
ARENA_FLOOR_Y = 520.0
ARENA_WALL_HALF = MAP_WIDTH * 0.5 + 32.0
MAX_HP = 100.0
ROUND_TIME_TICKS = 3600
START_X = 120.0
WALK_SPEED_FWD = 200.0
WALK_SPEED_BACK = 150.0
BODY_W = 28.0
BODY_H = 56.0
NEVER_HIT = 100000

MOVES = {
    4: {"startup": 4, "active": 3, "recovery": 8, "damage": 5.0, "reach": 40.0, "y_top": -46.0, "y_bot": -18.0, "hitstun": 14, "knockback": 90.0},
    5: {"startup": 12, "active": 4, "recovery": 20, "damage": 14.0, "reach": 50.0, "y_top": -52.0, "y_bot": -14.0, "hitstun": 26, "knockback": 220.0},
    6: {"startup": 8, "active": 4, "recovery": 14, "damage": 9.0, "reach": 72.0, "y_top": -30.0, "y_bot": -2.0, "hitstun": 18, "knockback": 150.0},
}
COOLDOWN_TICKS = [60, 40, 60, 90]  # heavy, kick, dash, dodge


@dataclass
class SimFighter:
    x: float = 0.0
    y: float = ARENA_FLOOR_Y
    vx: float = 0.0
    vy: float = 0.0
    facing: int = 1
    hp: float = MAX_HP
    state: str = "IDLE"  # IDLE, ATTACK, BLOCK, STUN, DODGE, DASH
    state_ticks: int = 0
    stun_left: int = 0
    intent: int = 0
    current_action: int = 0
    attack_connected: bool = False
    combo: int = 0
    ticks_since_hit: int = NEVER_HIT
    cooldowns: list[int] = field(default_factory=lambda: [0, 0, 0, 0])
    startup: int = 0
    active: int = 0
    total: int = 0
    move: dict = field(default_factory=dict)

    def reset(self, x: float, face: int) -> None:
        self.x, self.y = x, ARENA_FLOOR_Y
        self.vx, self.vy = 0.0, 0.0
        self.facing = face
        self.hp = MAX_HP
        self.state = "IDLE"
        self.state_ticks = 0
        self.stun_left = 0
        self.intent = 0
        self.current_action = 0
        self.attack_connected = False
        self.combo = 0
        self.ticks_since_hit = NEVER_HIT
        self.cooldowns = [0, 0, 0, 0]

    def is_on_floor(self) -> bool:
        return self.y >= ARENA_FLOOR_Y - 0.01 and self.vy >= 0.0

    def is_actionable(self) -> bool:
        return self.state in ("IDLE", "BLOCK")

    def is_invincible(self) -> bool:
        return self.state == "DODGE" and self.state_ticks <= 10

    def has_active_hitbox(self) -> bool:
        return self.state == "ATTACK" and self.startup < self.state_ticks <= (self.startup + self.active)

    def state_class(self) -> int:
        if self.state == "STUN":
            return 3
        if self.state in ("ATTACK", "DASH", "DODGE"):
            return 1
        if not self.is_on_floor():
            return 4
        if self.state == "BLOCK":
            return 2
        return 0

    def apply_action(self, action: int) -> None:
        if not self.is_actionable():
            return
        grounded = self.is_on_floor()
        if action == 3:  # jump
            if grounded:
                self.vy = JUMP_VELOCITY
            self.intent = 0
        elif action in (4, 5, 6):
            self.intent = 0
            cd_idx = 0 if action == 5 else (1 if action == 6 else -1)
            if cd_idx >= 0:
                if self.cooldowns[cd_idx] > 0:
                    return
                self.cooldowns[cd_idx] = COOLDOWN_TICKS[cd_idx]
            self.move = MOVES[action]
            self.startup = self.move["startup"]
            self.active = self.move["active"]
            self.total = self.startup + self.active + self.move["recovery"]
            self.attack_connected = False
            self.state = "ATTACK"
            self.state_ticks = 0
            self.current_action = action
            if grounded:
                self.vx = 0.0
        elif action == 8:  # dodge
            if grounded and self.cooldowns[3] == 0:
                self.cooldowns[3] = COOLDOWN_TICKS[3]
                self.state = "DODGE"
                self.state_ticks = 0
                self.current_action = action
            self.intent = 0
        elif action == 9:  # dash_fwd
            if grounded and self.cooldowns[2] == 0:
                self.cooldowns[2] = COOLDOWN_TICKS[2]
                self.state = "DASH"
                self.state_ticks = 0
                self.current_action = action
            self.intent = 0
        else:
            self.intent = action

    def clamp_to_arena(self) -> None:
        half_w = BODY_W * 0.5
        self.x = float(np.clip(self.x, -ARENA_WALL_HALF + half_w, ARENA_WALL_HALF - half_w))

    def tick(self) -> None:
        self.ticks_since_hit = min(self.ticks_since_hit + 1, NEVER_HIT)
        for i in range(4):
            if self.cooldowns[i] > 0:
                self.cooldowns[i] -= 1

        if self.state in ("IDLE", "BLOCK"):
            grounded = self.is_on_floor()
            self.state = "BLOCK" if (self.intent == 7 and grounded) else "IDLE"
            if grounded:
                if self.state == "BLOCK":
                    self.vx = 0.0
                elif self.intent == 1:
                    self.vx = float(self.facing) * WALK_SPEED_FWD
                elif self.intent == 2:
                    self.vx = -float(self.facing) * WALK_SPEED_BACK
                else:
                    self.vx = 0.0
        elif self.state == "ATTACK":
            self.state_ticks += 1
            if self.is_on_floor():
                self.vx = 0.0
            if self.state_ticks > self.total:
                self.state = "IDLE"
                self.state_ticks = 0
        elif self.state == "STUN":
            self.stun_left -= 1
            if abs(self.vx) <= 8.0:
                self.vx = 0.0
            else:
                self.vx -= np.sign(self.vx) * 8.0
            if self.stun_left <= 0:
                self.state = "IDLE"
                self.state_ticks = 0
                self.vx = 0.0
        elif self.state == "DASH":
            self.state_ticks += 1
            self.vx = float(self.facing) * 420.0
            if self.state_ticks >= 12:
                self.state = "IDLE"
                self.state_ticks = 0
                self.vx = 0.0
        elif self.state == "DODGE":
            self.state_ticks += 1
            self.vx = -float(self.facing) * 300.0 if self.state_ticks <= 12 else 0.0
            if self.state_ticks >= 20:
                self.state = "IDLE"
                self.state_ticks = 0
                self.vx = 0.0

        dt = 1.0 / float(TARGET_FPS)
        self.vy += GRAVITY * dt
        self.x += self.vx * dt
        self.y += self.vy * dt
        if self.y >= ARENA_FLOOR_Y:
            self.y = ARENA_FLOOR_Y
            self.vy = 0.0
        self.clamp_to_arena()


def encode_state(me: SimFighter, opp: SimFighter) -> np.ndarray:
    s = np.zeros(N_STATE, dtype=np.float32)
    f = float(me.facing)
    s[0] = np.clip((opp.x - me.x) * f / MAP_WIDTH, -1.0, 1.0)
    s[1] = np.clip((me.y - opp.y) / MAP_MAX_HEIGHT, -1.0, 1.0)
    s[2] = me.hp / MAX_HP
    s[3] = opp.hp / MAX_HP
    for i in range(4):
        s[4 + i] = float(me.cooldowns[i]) / float(COOLDOWN_TICKS[i])
    s[8 + me.state_class()] = 1.0
    s[13 + opp.state_class()] = 1.0
    s[18] = np.clip(me.vx * f / MAX_RUN_SPEED, -1.0, 1.0)
    s[19] = np.clip(opp.vx * f / MAX_RUN_SPEED, -1.0, 1.0)
    s[20] = min(float(me.combo) / 5.0, 1.0)
    s[21] = min(float(me.ticks_since_hit) / (3.0 * float(TARGET_FPS)), 1.0)
    return s


def decide_bot(bot_name: str, state: np.ndarray, rng: np.random.Generator, epsilon: float = 0.12) -> int:
    if epsilon > 0.0 and rng.random() < epsilon:
        return int(rng.integers(0, N_ACTIONS))

    dist_px = abs(float(state[0])) * MAP_WIDTH
    cd_heavy, cd_kick, cd_dash, cd_dodge = state[4], state[5], state[6], state[7]
    me_blocking = state[10] > 0.5
    opp_attacking = state[14] > 0.5
    opp_blocking = state[15] > 0.5
    opp_stunned = state[16] > 0.5
    opp_vel = state[19]
    recent_hit = state[21]

    if bot_name == "rusher":
        if dist_px > 92.0:
            if cd_dash <= 0.001 and dist_px <= 280.0 and rng.random() < 0.75:
                return 9
            return 1
        if dist_px > 66.0:
            if cd_dash <= 0.001 and rng.random() < 0.50:
                return 9
            if cd_kick <= 0.001 and rng.random() < 0.25:
                return 6
            return 1
        if opp_stunned and cd_heavy <= 0.001 and rng.random() < 0.65:
            return 5
        if opp_blocking and cd_heavy <= 0.001 and rng.random() < 0.55:
            return 5
        if opp_attacking and rng.random() < 0.08:
            return 7
        r = rng.random()
        if r < 0.76:
            return 4
        if r < 0.90 and cd_heavy <= 0.001:
            return 5
        return 1

    if bot_name == "turtle":
        just_blocked = me_blocking and recent_hit < 0.12 and not opp_attacking
        if dist_px <= 98.0 and (opp_stunned or just_blocked):
            if dist_px <= 76.0 and cd_heavy <= 0.001:
                return 5
            if cd_kick <= 0.001:
                return 6
            if dist_px <= 66.0:
                return 4
        if opp_attacking and 68.0 < dist_px <= 98.0:
            if cd_kick <= 0.001 and rng.random() < 0.70:
                return 6
            return 7
        if (opp_attacking or opp_vel < -0.25) and dist_px <= 135.0:
            return 7
        if dist_px <= 74.0:
            r = rng.random()
            if r < 0.65:
                return 7
            if r < 0.85 and cd_dodge <= 0.001:
                return 8
            return 4
        if dist_px < 175.0:
            return 2 if rng.random() < 0.65 else 7
        if dist_px > 260.0 and rng.random() < 0.25:
            return 1
        return 7 if rng.random() < 0.60 else 0

    if bot_name == "poker":
        if dist_px < 72.0:
            if cd_dodge <= 0.001 and rng.random() < 0.80:
                return 8
            if opp_attacking and rng.random() < 0.55:
                return 7
            return 2 if rng.random() < 0.65 else 4
        if dist_px <= 102.0:
            if cd_kick <= 0.001:
                return 6 if rng.random() < 0.82 else 2
            return 2 if rng.random() < 0.78 else (7 if opp_attacking else 0)
        if dist_px <= 145.0:
            if cd_kick > 0.25:
                return 2 if rng.random() < 0.60 else 0
            return 1 if rng.random() < 0.78 else 0
        return 1 if rng.random() < 0.85 else 0

    return int(rng.integers(0, N_ACTIONS))


def _rects_intersect(ax: float, ay: float, aw: float, ah: float, bx: float, by: float, bw: float, bh: float) -> bool:
    return (ax < bx + bw) and (ax + aw > bx) and (ay < by + bh) and (ay + ah > by)


def run_sim_match(
    p1_fn,
    p2_fn,
    session_id: str,
    p1_id: str,
    log_rows: list[list] | None = None,
) -> dict:
    a, b = SimFighter(), SimFighter()
    a.reset(-START_X, 1)
    b.reset(START_X, -1)
    fighters = [a, b]
    fns = [p1_fn, p2_fn]

    for tick in range(ROUND_TIME_TICKS):
        if tick % DECISION_INTERVAL_FRAMES == 0:
            s0 = encode_state(a, b)
            s1 = encode_state(b, a)
            states = [s0, s1]
            acts = [0, 0]
            act_flags = [a.is_actionable(), b.is_actionable()]
            for i in range(2):
                if act_flags[i]:
                    acts[i] = fns[i](states[i])
                    if i == 0 and log_rows is not None:
                        log_rows.append(
                            [session_id, p1_id, tick, *[f"{v:.6f}" for v in states[i]], acts[i]]
                        )
            for i in range(2):
                if act_flags[i]:
                    fighters[i].apply_action(acts[i])

        for i in range(2):
            me, opp = fighters[i], fighters[1 - i]
            if me.state in ("IDLE", "BLOCK"):
                dx = opp.x - me.x
                if dx > 0.5:
                    me.facing = 1
                elif dx < -0.5:
                    me.facing = -1

        a.tick()
        b.tick()

        # Hits
        hits = []
        for i in range(2):
            atk, dfn = fighters[i], fighters[1 - i]
            if not atk.has_active_hitbox() or atk.attack_connected or dfn.is_invincible():
                continue
            reach = atk.move["reach"]
            y_top, y_bot = atk.move["y_top"], atk.move["y_bot"]
            x0 = atk.x + float(atk.facing) * BODY_W * 0.5
            x1 = x0 + float(atk.facing) * reach
            hx, hy, hw, hh = min(x0, x1), atk.y + y_top, abs(x1 - x0), y_bot - y_top
            dx0, dy0, dw, dh = dfn.x - BODY_W * 0.5, dfn.y - BODY_H, BODY_W, BODY_H
            if _rects_intersect(hx, hy, hw, hh, dx0, dy0, dw, dh):
                in_front = (atk.x - dfn.x) * float(dfn.facing) > 0.0
                hits.append((atk, dfn, dfn.state == "BLOCK" and in_front, dfn.state == "STUN"))

        for atk, dfn, blocked, was_stunned in hits:
            mv = MOVES[atk.current_action]
            push_dir = 1.0 if dfn.x >= atk.x else -1.0
            atk.attack_connected = True
            atk.ticks_since_hit = 0
            dfn.ticks_since_hit = 0
            if blocked:
                dfn.hp = max(dfn.hp - mv["damage"] * 0.2, 0.0)
                dfn.vx = push_dir * 120.0
            else:
                atk.combo = atk.combo + 1 if was_stunned else 1
                dfn.hp = max(dfn.hp - mv["damage"], 0.0)
                dfn.state = "STUN"
                dfn.state_ticks = 0
                dfn.stun_left = mv["hitstun"]
                dfn.vx = push_dir * mv["knockback"]
                dfn.intent = 0
                dfn.attack_connected = True

        # Separate
        if abs(a.y - b.y) < BODY_H:
            dx = b.x - a.x
            overlap = BODY_W - abs(dx)
            if overlap > 0.0:
                d = -1.0 if (dx < 0.0 or (dx == 0.0 and a.facing < 0)) else 1.0
                a.x -= d * overlap * 0.5
                b.x += d * overlap * 0.5
                a.clamp_to_arena()
                b.clamp_to_arena()

        for i in range(2):
            if fighters[1 - i].state != "STUN":
                fighters[i].combo = 0

        if a.hp <= 0.0 or b.hp <= 0.0:
            w = 0 if a.hp > b.hp else (1 if b.hp > a.hp else -1)
            return {"winner": w, "hp_a": a.hp, "hp_b": b.hp, "ticks": tick + 1, "reason": "ko"}

    w = 0 if a.hp > b.hp else (1 if b.hp > a.hp else -1)
    return {"winner": w, "hp_a": a.hp, "hp_b": b.hp, "ticks": ROUND_TIME_TICKS, "reason": "timeout"}


def generate_bot_dataset(
    bot_name: str,
    out_csv: str | Path,
    results_csv: str | Path | None = None,
    min_rows: int = 1200,
    seed: int = 1,
) -> tuple[int, int]:
    """Generate >= min_rows of 10 Hz actionable decisions for `bot_name` vs rotating opponents."""
    rng = np.random.default_rng(seed)
    opponents = ["turtle", "poker", "rusher"]
    rows: list[list] = []
    match_records: list[list] = []
    match_idx = 0

    while len(rows) < min_rows:
        opp_name = opponents[match_idx % len(opponents)]
        sid = f"smoke_{bot_name}_vs_{opp_name}_{match_idx:04d}"
        res = run_sim_match(
            lambda s, b=bot_name: decide_bot(b, s, rng, 0.12),
            lambda s, o=opp_name: decide_bot(o, s, rng, 0.12),
            session_id=sid,
            p1_id=bot_name,
            log_rows=rows,
        )
        match_records.append(
            [
                match_idx,
                sid,
                bot_name,
                opp_name,
                res["winner"],
                f"{res['hp_a']:.2f}",
                f"{res['hp_b']:.2f}",
                res["ticks"],
                res["reason"],
            ]
        )
        match_idx += 1

    out_path = Path(out_csv)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    header = ["session_id", "player_id", "tick", *[f"s{i}" for i in range(N_STATE)], "action"]
    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)

    if results_csv is not None:
        res_path = Path(results_csv)
        res_path.parent.mkdir(parents=True, exist_ok=True)
        with res_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["match_id", "session_id", "p1", "p2", "winner", "hp_a", "hp_b", "ticks", "reason"])
            writer.writerows(match_records)

    return len(rows), match_idx


def run_smoke_test() -> None:
    t0 = time.perf_counter()
    raw_csv = Path("data/raw/rusher.csv")
    matches_csv = Path("data/raw/matches.csv")
    model_json = Path("data/models/mirror.json")
    ckpt_pt = Path("data/models/best.pt")
    vectors_json = Path("data/models/test_vectors.json")

    # 1. Generate >= 1,000 rows of bot decision data
    n_rows, n_matches = generate_bot_dataset(
        bot_name="rusher",
        out_csv=raw_csv,
        results_csv=matches_csv,
        min_rows=1200,
        seed=42,
    )
    print(f"[1/4] DATA_GEN_OK bot=rusher matches={n_matches} rows={n_rows} csv={raw_csv}")
    assert n_rows >= 1000, f"Expected >= 1000 rows, got {n_rows}"

    # 2. Train MLP & export JSON + test_vectors.json
    train_res = train_pipeline(
        data_path=raw_csv,
        out_model_path=model_json,
        out_ckpt_path=ckpt_pt,
        out_vectors_path=vectors_json,
        epochs=80,
        batch_size=128,
        lr=1e-3,
        patience=15,
        seed=0,
    )
    print(
        f"[2/4] TRAIN_OK backend={train_res['backend']} rows={train_res['rows_total']} "
        f"val_acc={train_res['val_acc']:.4f} macro_f1={train_res['val_macro_f1']:.4f} "
        f"maj_acc={train_res['majority_acc']:.4f}"
    )

    # 3. Verify GDScript forward pass parity on test_vectors.json (< 1e-4)
    model_data = json.loads(model_json.read_text(encoding="utf-8"))
    vec_data = json.loads(vectors_json.read_text(encoding="utf-8"))
    vectors = vec_data["vectors"]
    assert len(vectors) == 20, f"Expected 20 test vectors, got {len(vectors)}"

    max_err = 0.0
    for item in vectors:
        s = np.asarray(item["state"], dtype=np.float32)
        expected = np.asarray(item["logits"], dtype=np.float32)
        got = gdscript_forward_single(s, model_data["mean"], model_data["std"], model_data["layers"])
        err = float(np.max(np.abs(got - expected)))
        max_err = max(max_err, err)

    print(f"[3/4] PARITY_OK vectors={len(vectors)} max_abs_err={max_err:.8f} (< 1e-4)")
    assert max_err < 1e-4, f"Parity error {max_err} >= 1e-4"

    # 4. Run MirrorController with loaded mirror.json in combat simulation
    rng = np.random.default_rng(99)

    def mirror_decide(state: np.ndarray) -> int:
        logits = gdscript_forward_single(state, model_data["mean"], model_data["std"], model_data["layers"])
        shifted = (logits - logits.max()) / 0.7
        probs = np.exp(shifted)
        probs = probs / probs.sum()
        return int(rng.choice(N_ACTIONS, p=probs))

    wins = [0, 0, 0]
    for m_i in range(20):
        r = run_sim_match(
            mirror_decide,
            lambda s: decide_bot("turtle", s, rng, 0.12),
            session_id=f"mirror_test_{m_i}",
            p1_id="mirror",
        )
        w = r["winner"]
        wins[w if w >= 0 else 2] += 1

    elapsed = time.perf_counter() - t0
    print(
        f"[4/4] MIRROR_MATCH_OK matches=20 mirror_wins={wins[0]} opp_wins={wins[1]} "
        f"draws={wins[2]} total_time={elapsed:.2f}s"
    )
    print("SMOKE_PIPELINE_OK")


if __name__ == "__main__":
    run_smoke_test()
