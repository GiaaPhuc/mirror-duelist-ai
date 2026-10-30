"""Automated unit & integration tests for Week 3 deliverables."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

from dataset import N_ACTIONS, N_STATE, REQUIRED_COLS, load_dataset
from model import gdscript_forward_single
from smoke_test import decide_bot, generate_bot_dataset, run_sim_match
from train import train_pipeline


def test_three_bots_distinct_signatures() -> None:
    """Rusher, Turtle, and Poker must exhibit clearly distinct action distributions."""
    rng = np.random.default_rng(123)
    states = rng.uniform(0.0, 0.35, size=(600, N_STATE)).astype(np.float32)
    # Set cooldowns 0 for half, >0 for half
    states[:300, 4:8] = 0.0
    states[300:, 4:8] = 0.5

    hist: dict[str, np.ndarray] = {}
    for bot in ("rusher", "turtle", "poker"):
        actions = [decide_bot(bot, s, rng, epsilon=0.0) for s in states]
        counts = np.bincount(actions, minlength=N_ACTIONS).astype(np.float64)
        hist[bot] = counts / counts.sum()

    # Rusher prioritizes walk_fwd (1), light (4), dash_fwd (9)
    assert hist["rusher"][1] + hist["rusher"][4] + hist["rusher"][9] > 0.65
    # Turtle prioritizes block (7) and walk_back (2)
    assert hist["turtle"][7] + hist["turtle"][2] > 0.55
    # Poker uses kick (6), walk_back (2), dodge (8) significantly more than others
    assert hist["poker"][6] + hist["poker"][8] > hist["rusher"][6] + hist["rusher"][8]


def test_500_bot_vs_bot_matches_and_pipeline(tmp_path: Path) -> None:
    """Run 500 bot-vs-bot matches, verify CSV logging, train MLP, and check GDScript parity < 1e-4."""
    rng = np.random.default_rng(7)
    bots = ["rusher", "turtle", "poker"]
    wins = [0, 0, 0]
    for i in range(500):
        b1 = bots[i % 3]
        b2 = bots[(i + 1) % 3]
        res = run_sim_match(
            lambda s, b=b1: decide_bot(b, s, rng, 0.12),
            lambda s, b=b2: decide_bot(b, s, rng, 0.12),
            session_id=f"m_{i}",
            p1_id=b1,
        )
        assert res["reason"] in ("ko", "timeout")
        assert 1 <= res["ticks"] <= 3600
        assert 0.0 <= res["hp_a"] <= 100.0
        assert 0.0 <= res["hp_b"] <= 100.0
        w = res["winner"]
        wins[w if w >= 0 else 2] += 1

    assert sum(wins) == 500

    # Generate >= 1000 rows CSV and run full train -> export -> parity check
    csv_path = tmp_path / "rusher.csv"
    matches_csv = tmp_path / "matches.csv"
    model_json = tmp_path / "mirror.json"
    ckpt_pt = tmp_path / "best.pt"
    vec_json = tmp_path / "test_vectors.json"

    n_rows, _ = generate_bot_dataset("rusher", csv_path, matches_csv, min_rows=1050, seed=11)
    assert n_rows >= 1000

    X, y, groups, df = load_dataset(csv_path)
    assert list(df.columns) == REQUIRED_COLS
    assert (df["tick"] % 6 == 0).all()
    assert X.shape == (n_rows, N_STATE)

    res = train_pipeline(
        data_path=csv_path,
        out_model_path=model_json,
        out_ckpt_path=ckpt_pt,
        out_vectors_path=vec_json,
        epochs=60,
        batch_size=128,
        seed=0,
    )
    assert res["val_acc"] > res["majority_acc"]
    assert res["max_abs_err"] < 1e-4

    model_payload = json.loads(model_json.read_text(encoding="utf-8"))
    vec_payload = json.loads(vec_json.read_text(encoding="utf-8"))
    assert len(vec_payload["vectors"]) == 20
    for item in vec_payload["vectors"]:
        gd_out = gdscript_forward_single(
            item["state"], model_payload["mean"], model_payload["std"], model_payload["layers"]
        )
        err = float(np.max(np.abs(gd_out - np.asarray(item["logits"], dtype=np.float32))))
        assert err < 1e-4
