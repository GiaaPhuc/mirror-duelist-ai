"""Export trained MLP weights + normalization parameters to JSON for Godot (`mirror.json`),
and generate 20 random state-logit test vectors (`test_vectors.json`) for GDScript parity testing.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import numpy as np

from dataset import N_ACTIONS, N_STATE
from model import HAS_TORCH, build_torch_mlp, extract_torch_layers, gdscript_forward_single

if HAS_TORCH:
    import torch


def forward_normalized_layers(
    state_batch: np.ndarray,
    mean: np.ndarray,
    std: np.ndarray,
    layers: list[dict[str, Any]],
) -> np.ndarray:
    """Compute model logits for raw (unnormalized) state vectors of shape [B, N_STATE]."""
    x = ((state_batch.astype(np.float32) - mean.astype(np.float32)) / std.astype(np.float32)).astype(np.float32)
    if HAS_TORCH:
        with torch.no_grad():
            a = torch.tensor(x, dtype=torch.float32)
            for li, layer in enumerate(layers):
                W = torch.tensor(layer["W"], dtype=torch.float32)
                b = torch.tensor(layer["b"], dtype=torch.float32)
                a = a @ W.T + b
                if li < len(layers) - 1:
                    a = torch.relu(a)
            return a.cpu().numpy().astype(np.float32)

    a = x
    for li, layer in enumerate(layers):
        W = np.asarray(layer["W"], dtype=np.float32)
        b = np.asarray(layer["b"], dtype=np.float32)
        a = (a @ W.T + b).astype(np.float32)
        if li < len(layers) - 1:
            a = np.maximum(a, np.float32(0.0))
    return a


def export_model_and_vectors(
    mean: np.ndarray,
    std: np.ndarray,
    layers: list[dict[str, Any]],
    out_model_path: str | Path = "data/models/mirror.json",
    out_vectors_path: str | Path | None = "data/models/test_vectors.json",
    n_vectors: int = 20,
    seed: int = 0,
    tolerance: float = 1e-4,
) -> dict[str, Any]:
    """Write `mirror.json` and `test_vectors.json`, and verify GDScript reference parity < 1e-4."""
    out_model = Path(out_model_path)
    out_model.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "mean": [float(v) for v in mean.tolist()],
        "std": [float(v) for v in std.tolist()],
        "layers": layers,
    }
    with out_model.open("w", encoding="utf-8") as f:
        json.dump(payload, f)

    rng = np.random.default_rng(seed)
    states = rng.uniform(-1.0, 1.0, size=(n_vectors, N_STATE)).astype(np.float32)
    logits = forward_normalized_layers(states, mean, std, layers)

    max_abs_err = 0.0
    vectors_list: list[dict[str, list[float]]] = []
    for i in range(n_vectors):
        gd_logits = gdscript_forward_single(states[i], payload["mean"], payload["std"], payload["layers"])
        err = float(np.max(np.abs(gd_logits - logits[i])))
        if err > max_abs_err:
            max_abs_err = err
        vectors_list.append(
            {
                "state": [float(v) for v in states[i].tolist()],
                "logits": [float(v) for v in logits[i].tolist()],
            }
        )

    if out_vectors_path is not None:
        out_vec = Path(out_vectors_path)
        out_vec.parent.mkdir(parents=True, exist_ok=True)
        vec_payload = {
            "model_path": str(out_model).replace("\\", "/"),
            "tolerance": tolerance,
            "max_abs_err_python_vs_gdscript_ref": max_abs_err,
            "vectors": vectors_list,
        }
        with out_vec.open("w", encoding="utf-8") as f:
            json.dump(vec_payload, f, indent=2)

    if max_abs_err >= tolerance:
        raise AssertionError(f"Parity check failed: max_abs_err={max_abs_err:.8f} >= {tolerance}")

    return {
        "model_path": str(out_model),
        "vectors_path": str(out_vectors_path) if out_vectors_path else "",
        "n_vectors": n_vectors,
        "max_abs_err": max_abs_err,
    }


def load_checkpoint(ckpt_path: str | Path) -> tuple[np.ndarray, np.ndarray, list[dict[str, Any]]]:
    """Load checkpoint saved by train.py (supports both PyTorch .pt and pickle/json bundle)."""
    p = Path(ckpt_path)
    if not p.exists():
        raise FileNotFoundError(f"Checkpoint not found: {p}")

    if HAS_TORCH:
        try:
            ckpt = torch.load(p, map_location="cpu", weights_only=False)
            if isinstance(ckpt, dict) and "state_dict" in ckpt:
                model = build_torch_mlp(N_STATE, 64, N_ACTIONS)
                model.load_state_dict(ckpt["state_dict"])
                layers = extract_torch_layers(model)
                mean = np.asarray(ckpt["mean"], dtype=np.float32)
                std = np.asarray(ckpt["std"], dtype=np.float32)
                return mean, std, layers
        except Exception:
            pass

    data = json.loads(p.read_text(encoding="utf-8"))
    mean = np.asarray(data["mean"], dtype=np.float32)
    std = np.asarray(data["std"], dtype=np.float32)
    layers = data["layers"]
    return mean, std, layers


def main() -> None:
    parser = argparse.ArgumentParser(description="Export checkpoint to mirror.json and test_vectors.json")
    parser.add_argument("--checkpoint", type=str, default="data/models/best.pt")
    parser.add_argument("--output", type=str, default="data/models/mirror.json")
    parser.add_argument("--test-vectors", type=str, default="data/models/test_vectors.json")
    parser.add_argument("--n-vectors", type=int, default=20)
    parser.add_argument("--seed", type=int, default=0)
    args = parser.parse_args()

    mean, std, layers = load_checkpoint(args.checkpoint)
    info = export_model_and_vectors(
        mean=mean,
        std=std,
        layers=layers,
        out_model_path=args.output,
        out_vectors_path=args.test_vectors,
        n_vectors=args.n_vectors,
        seed=args.seed,
    )
    print(
        f"EXPORT_OK model={info['model_path']} vectors={info['vectors_path']} "
        f"n={info['n_vectors']} max_abs_err={info['max_abs_err']:.8f}"
    )


if __name__ == "__main__":
    main()
