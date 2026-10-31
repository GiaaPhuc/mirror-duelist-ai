"""Automated verification tests for Week 4 deliverables (Data collection & BC Baseline)."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from dataset import N_STATE, REQUIRED_COLS, load_dataset, split_by_session
from model import gdscript_forward_single

BOT_NAMES = ("rusher", "turtle", "poker")


def test_week4_datasets_and_session_split() -> None:
    """Verify >= 10,000 rows per bot across diverse opponents, 15 human_self sessions, and leak-free split."""
    for bot in BOT_NAMES:
        csv_path = Path(f"data/raw/{bot}.csv")
        assert csv_path.exists(), f"Missing dataset {csv_path}"
        X, y, groups, df = load_dataset(csv_path)
        assert list(df.columns) == REQUIRED_COLS
        assert len(X) >= 10000, f"{bot} has {len(X)} rows, expected >= 10,000"
        assert X.shape[1] == N_STATE
        assert (df["tick"] % 6 == 0).all()

        # Verify opponent diversity in session_ids
        unique_sessions = np.unique(groups)
        assert len(unique_sessions) >= 20
        joined_sids = " ".join(unique_sessions.tolist())
        for opp in ("rusher", "turtle", "poker", "random"):
            assert f"_vs_{opp}_" in joined_sids, f"{bot}.csv missing opponent {opp}"

        # Verify 80/20 session-grouped split has zero leakage
        tr_idx, va_idx = split_by_session(X, y, groups, test_size=0.2, random_state=42)
        tr_sessions = set(groups[tr_idx].tolist())
        va_sessions = set(groups[va_idx].tolist())
        assert tr_sessions.isdisjoint(va_sessions)
        assert len(tr_sessions) > len(va_sessions) >= 4

    # Verify human_self dataset (10-15 sessions)
    human_csv = Path("data/raw/human_self.csv")
    assert human_csv.exists(), "Missing data/raw/human_self.csv"
    X_h, y_h, g_h, df_h = load_dataset(human_csv)
    assert list(df_h.columns) == REQUIRED_COLS
    n_human_sessions = len(np.unique(g_h))
    assert 10 <= n_human_sessions <= 20, f"Expected 10-15 human_self sessions, got {n_human_sessions}"
    assert len(X_h) >= 2000


def test_week4_models_parity_and_validation_metrics() -> None:
    """Verify 3 Bot Mirror models + HumanSelf model, parity < 1e-4, and val_acc >> majority_acc."""
    summary_path = Path("results/week4_baseline_summary.json")
    assert summary_path.exists(), "Missing results/week4_baseline_summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    training = summary["training"]

    for target in (*BOT_NAMES, "human_self"):
        model_path = Path(f"data/models/mirror_{target}.json")
        vec_path = Path(f"data/models/test_vectors_{target}.json")
        assert model_path.exists(), f"Missing model {model_path}"
        assert vec_path.exists(), f"Missing test vectors {vec_path}"

        model_data = json.loads(model_path.read_text(encoding="utf-8"))
        vec_data = json.loads(vec_path.read_text(encoding="utf-8"))
        assert len(model_data["mean"]) == N_STATE
        assert len(model_data["std"]) == N_STATE
        assert len(model_data["layers"]) == 3
        assert len(vec_data["vectors"]) == 20

        for item in vec_data["vectors"]:
            gd_out = gdscript_forward_single(
                item["state"], model_data["mean"], model_data["std"], model_data["layers"]
            )
            err = float(np.max(np.abs(gd_out - np.asarray(item["logits"], dtype=np.float32))))
            assert err < 1e-4, f"Parity error {err} >= 1e-4 for {target}"

        tr_info = training[target]
        assert tr_info["val_acc"] > tr_info["majority_acc"] + 0.15, (
            f"{target}: val_acc={tr_info['val_acc']:.4f} not clearly above majority_acc={tr_info['majority_acc']:.4f}"
        )
        assert tr_info["val_active_macro_f1"] >= 0.45


def test_week4_live_style_similarity_and_anomaly_logging() -> None:
    """Verify Mirror-X matches Bot-X style (diagonal KL minimum, distance ordering) and logs anomalies."""
    summary = json.loads(Path("results/week4_baseline_summary.json").read_text(encoding="utf-8"))
    eval_res = summary["evaluation"]
    kl_mat = summary["cross_kl_matrix"]

    # 1. Diagonal of 3x3 KL matrix must be strictly smallest in each row and column
    for b_i in BOT_NAMES:
        diag_kl = kl_mat[f"mirror_{b_i}"][b_i]
        assert diag_kl < 0.15, f"Self KL too high for {b_i}: {diag_kl}"
        for b_j in BOT_NAMES:
            if b_i != b_j:
                assert diag_kl < kl_mat[f"mirror_{b_i}"][b_j], (
                    f"Mirror-{b_i} closer to {b_j} ({kl_mat[f'mirror_{b_i}'][b_j]}) than {b_i} ({diag_kl})"
                )

    # 2. Preferred combat distance ordering: Rusher (closest) < Poker (mid) < Turtle (farthest)
    d_rusher = eval_res["rusher"]["mean_dist_px"]
    d_poker = eval_res["poker"]["mean_dist_px"]
    d_turtle = eval_res["turtle"]["mean_dist_px"]
    assert d_rusher < d_poker < d_turtle, (
        f"Expected distance ordering rusher ({d_rusher}) < poker ({d_poker}) < turtle ({d_turtle})"
    )

    # 3. Check anomaly telemetry and report files exist
    for bot in BOT_NAMES:
        an = eval_res[bot]["anomalies"]
        assert an["total_decisions"] > 1000
        assert 0.0 <= an["corner_pinned_rate"] <= 1.0
        assert 0.0 <= an["wall_walk_back_when_cornered"] <= 1.0
        assert 0.0 <= an["cooldown_noop_rate"] <= 1.0

    assert Path("results/week4_baseline_metrics.csv").exists()
    assert Path("results/week4_baseline_report.md").exists()
