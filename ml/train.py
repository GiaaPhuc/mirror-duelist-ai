"""Behavior Cloning trainer for Mirror Duelist (MLP 22 -> 64 -> 64 -> 10).

Features (per SPEC.md & Implementation Plan Section 11.1 & Week 4):
- Session-grouped train/val split (80/20) to prevent frame leakage
- Train-split feature standardization (mean, std)
- Inverse-sqrt class frequency weighted cross-entropy
- Adam optimizer + early stopping on validation loss
- Exports `best.pt`, `mirror.json` (with mean/std + layers), and `test_vectors.json`
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import numpy as np

from dataset import (
    N_ACTIONS,
    N_STATE,
    compute_class_weights,
    compute_metrics,
    compute_norm_stats,
    load_dataset,
    split_by_session,
)
from export_json import export_model_and_vectors
from model import HAS_TORCH, NumpyMLP, build_torch_mlp, extract_torch_layers

if HAS_TORCH:
    import torch
    import torch.nn as nn


def _train_torch(
    Xtr: np.ndarray,
    ytr: np.ndarray,
    Xva: np.ndarray,
    yva: np.ndarray,
    class_weights: np.ndarray,
    epochs: int,
    batch_size: int,
    lr: float,
    patience: int,
    seed: int,
) -> tuple[list[dict[str, list]], float, np.ndarray, dict[str, Any], int, int]:
    torch.manual_seed(seed)
    np.random.seed(seed)

    model = build_torch_mlp(N_STATE, 64, N_ACTIONS)
    loss_fn = nn.CrossEntropyLoss(weight=torch.tensor(class_weights, dtype=torch.float32))
    opt = torch.optim.Adam(model.parameters(), lr=lr)

    Xtr_t = torch.tensor(Xtr, dtype=torch.float32)
    ytr_t = torch.tensor(ytr, dtype=torch.long)
    Xva_t = torch.tensor(Xva, dtype=torch.float32)
    yva_t = torch.tensor(yva, dtype=torch.long)

    best_loss = float("inf")
    best_state: dict[str, Any] | None = None
    best_epoch = 1
    epochs_ran = 0
    wait = 0

    for epoch in range(epochs):
        epochs_ran = epoch + 1
        model.train()
        perm = torch.randperm(len(Xtr_t))
        for i in range(0, len(perm), batch_size):
            idx = perm[i : i + batch_size]
            opt.zero_grad()
            loss = loss_fn(model(Xtr_t[idx]), ytr_t[idx])
            loss.backward()
            opt.step()

        model.eval()
        with torch.no_grad():
            val_logits = model(Xva_t)
            val_loss = float(loss_fn(val_logits, yva_t).item())

        if val_loss < best_loss - 1e-6:
            best_loss = val_loss
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}
            best_epoch = epochs_ran
            wait = 0
        else:
            wait += 1
            if wait >= patience:
                break

    if best_state is not None:
        model.load_state_dict(best_state)

    model.eval()
    with torch.no_grad():
        val_preds = model(Xva_t).argmax(dim=1).cpu().numpy()

    layers = extract_torch_layers(model)
    return layers, best_loss, val_preds, model.state_dict(), epochs_ran, best_epoch


def _train_numpy(
    Xtr: np.ndarray,
    ytr: np.ndarray,
    Xva: np.ndarray,
    yva: np.ndarray,
    class_weights: np.ndarray,
    epochs: int,
    batch_size: int,
    lr: float,
    patience: int,
    seed: int,
) -> tuple[list[dict[str, list]], float, np.ndarray, int, int]:
    rng = np.random.default_rng(seed)
    model = NumpyMLP(N_STATE, 64, N_ACTIONS, seed=seed)

    mW = [np.zeros_like(w) for w in model.W]
    vW = [np.zeros_like(w) for w in model.W]
    mb = [np.zeros_like(b) for b in model.b]
    vb = [np.zeros_like(b) for b in model.b]
    beta1, beta2, eps = 0.9, 0.999, 1e-8
    step_t = 0

    best_loss = float("inf")
    best_state = model.get_state()
    best_epoch = 1
    epochs_ran = 0
    wait = 0

    for epoch in range(epochs):
        epochs_ran = epoch + 1
        perm = rng.permutation(len(Xtr))
        for i in range(0, len(perm), batch_size):
            idx = perm[i : i + batch_size]
            _, gW, gb = model.loss_and_grads(Xtr[idx], ytr[idx], class_weights)
            step_t += 1
            b1_corr = 1.0 - beta1**step_t
            b2_corr = 1.0 - beta2**step_t
            for li in range(len(model.W)):
                mW[li] = beta1 * mW[li] + (1.0 - beta1) * gW[li]
                vW[li] = beta2 * vW[li] + (1.0 - beta2) * (gW[li] * gW[li])
                m_hat = mW[li] / b1_corr
                v_hat = vW[li] / b2_corr
                model.W[li] = (model.W[li] - lr * m_hat / (np.sqrt(v_hat) + eps)).astype(np.float32)

                mb[li] = beta1 * mb[li] + (1.0 - beta1) * gb[li]
                vb[li] = beta2 * vb[li] + (1.0 - beta2) * (gb[li] * gb[li])
                mb_hat = mb[li] / b1_corr
                vb_hat = vb[li] / b2_corr
                model.b[li] = (model.b[li] - lr * mb_hat / (np.sqrt(vb_hat) + eps)).astype(np.float32)

        val_loss = model.evaluate_loss(Xva, yva, class_weights)
        if val_loss < best_loss - 1e-6:
            best_loss = val_loss
            best_state = model.get_state()
            best_epoch = epochs_ran
            wait = 0
        else:
            wait += 1
            if wait >= patience:
                break

    model.set_state(best_state)
    val_preds = model.forward(Xva).argmax(axis=1)
    return model.to_layers_list(), best_loss, val_preds, epochs_ran, best_epoch


def train_pipeline(
    data_path: str | Path,
    out_model_path: str | Path = "data/models/mirror.json",
    out_ckpt_path: str | Path = "data/models/best.pt",
    out_vectors_path: str | Path = "data/models/test_vectors.json",
    epochs: int = 120,
    batch_size: int = 256,
    lr: float = 1e-3,
    patience: int = 15,
    seed: int = 0,
) -> dict[str, Any]:
    t0 = time.perf_counter()
    X, y, groups, _ = load_dataset(data_path)
    tr_idx, va_idx = split_by_session(X, y, groups, test_size=0.2, random_state=seed)

    mean, std = compute_norm_stats(X[tr_idx])
    Xtr = ((X[tr_idx] - mean) / std).astype(np.float32)
    Xva = ((X[va_idx] - mean) / std).astype(np.float32)
    ytr, yva = y[tr_idx], y[va_idx]

    w = compute_class_weights(ytr, N_ACTIONS)

    ckpt_file = Path(out_ckpt_path)
    ckpt_file.parent.mkdir(parents=True, exist_ok=True)

    if HAS_TORCH:
        layers, best_val_loss, val_preds, state_dict, epochs_ran, best_epoch = _train_torch(
            Xtr, ytr, Xva, yva, w, epochs, batch_size, lr, patience, seed
        )
        torch.save(
            {
                "state_dict": state_dict,
                "mean": mean.tolist(),
                "std": std.tolist(),
                "layers": layers,
            },
            ckpt_file,
        )
        backend = "pytorch"
    else:
        layers, best_val_loss, val_preds, epochs_ran, best_epoch = _train_numpy(
            Xtr, ytr, Xva, yva, w, epochs, batch_size, lr, patience, seed
        )
        ckpt_file.write_text(
            json.dumps({"mean": mean.tolist(), "std": std.tolist(), "layers": layers}),
            encoding="utf-8",
        )
        backend = "numpy-fallback"

    metrics = compute_metrics(yva, val_preds, N_ACTIONS)
    export_info = export_model_and_vectors(
        mean=mean,
        std=std,
        layers=layers,
        out_model_path=out_model_path,
        out_vectors_path=out_vectors_path,
        n_vectors=20,
        seed=seed,
    )
    elapsed = time.perf_counter() - t0

    return {
        "backend": backend,
        "data_path": str(data_path),
        "rows_total": len(X),
        "rows_train": len(Xtr),
        "rows_val": len(Xva),
        "sessions_total": int(len(np.unique(groups))),
        "sessions_train": int(len(np.unique(groups[tr_idx]))),
        "sessions_val": int(len(np.unique(groups[va_idx]))),
        "epochs_ran": epochs_ran,
        "best_epoch": best_epoch,
        "val_loss": best_val_loss,
        "val_acc": metrics["accuracy"],
        "val_macro_f1": metrics["macro_f1"],
        "val_active_macro_f1": metrics["active_macro_f1"],
        "val_weighted_f1": metrics["weighted_f1"],
        "majority_acc": metrics["majority_acc"],
        "majority_class": metrics["majority_class"],
        "majority_action": metrics["majority_action"],
        "per_class": metrics["per_class"],
        "class_weights": [round(float(v), 4) for v in w.tolist()],
        "max_abs_err": export_info["max_abs_err"],
        "elapsed_s": elapsed,
        "model_path": str(out_model_path),
        "ckpt_path": str(out_ckpt_path),
        "vectors_path": str(out_vectors_path),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Train Behavior Cloning MLP and export JSON for Godot.")
    parser.add_argument("--data", type=str, default="data/raw/rusher.csv", help="Path to CSV dataset")
    parser.add_argument("--out-model", type=str, default="data/models/mirror.json")
    parser.add_argument("--out-ckpt", type=str, default="data/models/best.pt")
    parser.add_argument("--out-vectors", type=str, default="data/models/test_vectors.json")
    parser.add_argument("--summary-json", type=str, default="", help="Optional path to save training metrics JSON")
    parser.add_argument("--epochs", type=int, default=120)
    parser.add_argument("--batch-size", type=int, default=256)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--patience", type=int, default=15)
    parser.add_argument("--seed", type=int, default=0)
    args = parser.parse_args()

    res = train_pipeline(
        data_path=args.data,
        out_model_path=args.out_model,
        out_ckpt_path=args.out_ckpt,
        out_vectors_path=args.out_vectors,
        epochs=args.epochs,
        batch_size=args.batch_size,
        lr=args.lr,
        patience=args.patience,
        seed=args.seed,
    )
    if args.summary_json:
        summary_path = Path(args.summary_json)
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(json.dumps(res, indent=2, ensure_ascii=False), encoding="utf-8")

    print(
        f"TRAIN_OK backend={res['backend']} rows={res['rows_total']} "
        f"(train={res['rows_train']}/{res['sessions_train']}s, val={res['rows_val']}/{res['sessions_val']}s) "
        f"best_ep={res['best_epoch']}/{res['epochs_ran']} "
        f"val_loss={res['val_loss']:.4f} val_acc={res['val_acc']:.4f} "
        f"macro_f1={res['val_macro_f1']:.4f} active_f1={res['val_active_macro_f1']:.4f} "
        f"maj_acc={res['majority_acc']:.4f}({res['majority_action']}) "
        f"parity_max_err={res['max_abs_err']:.8f} time={res['elapsed_s']:.2f}s"
    )


if __name__ == "__main__":
    main()
