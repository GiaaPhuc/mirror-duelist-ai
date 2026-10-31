"""Dataset loading, group-based train/val splitting, normalization, and metrics for Mirror Duelist."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Sequence

import numpy as np
import pandas as pd

N_STATE = 22
N_ACTIONS = 10

ACTION_NAMES: list[str] = [
    "idle",
    "walk_fwd",
    "walk_back",
    "jump",
    "light",
    "heavy",
    "kick",
    "block",
    "dodge",
    "dash_fwd",
]

STATE_COLS: list[str] = [f"s{i}" for i in range(N_STATE)]
REQUIRED_COLS: list[str] = ["session_id", "player_id", "tick", *STATE_COLS, "action"]


def load_dataset(
    paths: str | Path | Sequence[str | Path],
) -> tuple[np.ndarray, np.ndarray, np.ndarray, pd.DataFrame]:
    """Load one or more CSV logs produced by DataLogger."""
    if isinstance(paths, (str, Path)):
        path_list = [Path(paths)]
    else:
        path_list = [Path(p) for p in paths]

    frames: list[pd.DataFrame] = []
    for p in path_list:
        if not p.exists():
            raise FileNotFoundError(f"Dataset CSV not found: {p}")
        df_part = pd.read_csv(p)
        missing = [c for c in REQUIRED_COLS if c not in df_part.columns]
        if missing:
            raise ValueError(f"CSV {p} missing required columns: {missing}")
        frames.append(df_part)

    df = pd.concat(frames, ignore_index=True)
    if len(df) == 0:
        raise ValueError("Dataset is empty (0 rows).")

    X = df[STATE_COLS].to_numpy(dtype=np.float32)
    y = df["action"].to_numpy(dtype=np.int64)
    groups = df["session_id"].astype(str).to_numpy()

    if np.isnan(X).any():
        raise ValueError("Dataset contains NaN values in state columns.")
    if (y < 0).any() or (y >= N_ACTIONS).any():
        raise ValueError(f"Action labels out of range [0, {N_ACTIONS - 1}].")

    return X, y, groups, df


def split_by_session(
    X: np.ndarray,
    y: np.ndarray,
    groups: np.ndarray,
    test_size: float = 0.2,
    random_state: int = 0,
) -> tuple[np.ndarray, np.ndarray]:
    """Split indices into (train_idx, val_idx) grouped by session_id to prevent frame leakage."""
    unique_groups = np.unique(groups)
    if len(unique_groups) < 2:
        # Fallback for single-session smoke data: chronological split (no random frame leakage)
        n = len(X)
        split_at = max(1, min(n - 1, int(round(n * (1.0 - test_size)))))
        all_idx = np.arange(n, dtype=np.int64)
        return all_idx[:split_at], all_idx[split_at:]

    try:
        from sklearn.model_selection import GroupShuffleSplit

        gss = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=random_state)
        tr_idx, va_idx = next(gss.split(X, y, groups))
        tr_idx = tr_idx.astype(np.int64)
        va_idx = va_idx.astype(np.int64)
    except ImportError:
        rng = np.random.default_rng(random_state)
        perm_groups = rng.permutation(unique_groups)
        n_val_groups = max(1, min(len(unique_groups) - 1, int(round(len(unique_groups) * test_size))))
        val_groups = set(perm_groups[:n_val_groups].tolist())
        is_val = np.array([g in val_groups for g in groups], dtype=bool)
        tr_idx = np.flatnonzero(~is_val).astype(np.int64)
        va_idx = np.flatnonzero(is_val).astype(np.int64)

    # Guarantee zero session leakage between train and val
    assert set(groups[tr_idx]).isdisjoint(set(groups[va_idx])), "Session leakage detected between train and val!"
    return tr_idx, va_idx


def compute_norm_stats(X_train: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Compute per-feature mean and std on training split only.

    Constant or near-constant features (e.g. one-hot states like `stunned` that are always 0
    when actionable) get std=1.0 so unseen non-zero values at test time do not explode by 1e6.
    """
    mean = X_train.mean(axis=0).astype(np.float32)
    raw_std = X_train.std(axis=0).astype(np.float32)
    std = np.where(raw_std < 1e-2, np.float32(1.0), raw_std).astype(np.float32)
    return mean, std


def compute_class_weights(y_train: np.ndarray, n_actions: int = N_ACTIONS) -> np.ndarray:
    """Inverse square-root class frequency weights normalized to mean 1.0 (Section 11.1)."""
    counts = np.bincount(y_train, minlength=n_actions).astype(np.float32) + 1.0
    w = 1.0 / np.sqrt(counts)
    w = w / w.mean()
    return w.astype(np.float32)


def compute_metrics(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    n_actions: int = N_ACTIONS,
    active_min_freq: float = 0.025,
) -> dict[str, Any]:
    """Compute accuracy, macro-F1, active-class macro-F1, weighted-F1, majority baseline, and per-class stats."""
    n_total = len(y_true)
    if n_total == 0:
        return {
            "accuracy": 0.0,
            "macro_f1": 0.0,
            "active_macro_f1": 0.0,
            "weighted_f1": 0.0,
            "majority_acc": 0.0,
            "majority_class": 0,
            "majority_action": ACTION_NAMES[0],
            "per_class": {},
        }

    acc = float((y_true == y_pred).mean())
    counts = np.bincount(y_true, minlength=n_actions)
    maj_cls = int(counts.argmax())
    majority_acc = float(counts[maj_cls] / n_total)

    f1_list: list[float] = []
    active_f1_list: list[float] = []
    weighted_f1_sum = 0.0
    per_class: dict[str, dict[str, float | int]] = {}

    for c in range(n_actions):
        tp = int(((y_true == c) & (y_pred == c)).sum())
        fp = int(((y_true != c) & (y_pred == c)).sum())
        fn = int(((y_true == c) & (y_pred != c)).sum())
        support = int(counts[c])
        freq = float(support / n_total)
        prec = float(tp / (tp + fp)) if (tp + fp) > 0 else 0.0
        rec = float(tp / (tp + fn)) if (tp + fn) > 0 else 0.0
        denom = 2 * tp + fp + fn
        f1 = (2.0 * tp / denom) if denom > 0 else 0.0

        name = ACTION_NAMES[c] if c < len(ACTION_NAMES) else f"a{c}"
        per_class[name] = {
            "id": c,
            "support": support,
            "freq": round(freq, 4),
            "precision": round(prec, 4),
            "recall": round(rec, 4),
            "f1": round(f1, 4),
        }

        if tp + fp + fn > 0:
            f1_list.append(f1)
        if freq >= active_min_freq:
            active_f1_list.append(f1)
        weighted_f1_sum += f1 * support

    macro_f1 = float(np.mean(f1_list)) if f1_list else 0.0
    active_macro_f1 = float(np.mean(active_f1_list)) if active_f1_list else macro_f1
    weighted_f1 = float(weighted_f1_sum / n_total)

    return {
        "accuracy": acc,
        "macro_f1": macro_f1,
        "active_macro_f1": active_macro_f1,
        "weighted_f1": weighted_f1,
        "majority_acc": majority_acc,
        "majority_class": maj_cls,
        "majority_action": ACTION_NAMES[maj_cls] if maj_cls < len(ACTION_NAMES) else str(maj_cls),
        "per_class": per_class,
    }
