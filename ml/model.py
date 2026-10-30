"""MLP architecture (22 -> 64 -> 64 -> 10, ReLU) for Behavior Cloning.

Uses PyTorch (`torch.nn`) as primary backend and provides a mathematically identical
float32 NumPy backend + GDScript reference forward pass for verification.
"""

from __future__ import annotations

from typing import Any
import numpy as np

from dataset import N_ACTIONS, N_STATE

try:
    import torch
    import torch.nn as nn

    HAS_TORCH = True
except ImportError:
    torch = None  # type: ignore[assignment]
    nn = None  # type: ignore[assignment]
    HAS_TORCH = False


def build_torch_mlp(n_state: int = N_STATE, hidden: int = 64, n_actions: int = N_ACTIONS) -> Any:
    """Build the canonical 22 -> 64 -> 64 -> 10 MLP in PyTorch."""
    if not HAS_TORCH:
        raise RuntimeError("PyTorch is not installed.")
    return nn.Sequential(
        nn.Linear(n_state, hidden),
        nn.ReLU(),
        nn.Linear(hidden, hidden),
        nn.ReLU(),
        nn.Linear(hidden, n_actions),
    )


def extract_torch_layers(model: Any) -> list[dict[str, list]]:
    """Extract Linear layers in [out][in] format matching game/scripts/mlp.gd."""
    layers = [m for m in model if isinstance(m, nn.Linear)]
    return [
        {
            "W": l.weight.detach().cpu().to(torch.float32).tolist(),
            "b": l.bias.detach().cpu().to(torch.float32).tolist(),
        }
        for l in layers
    ]


class NumpyMLP:
    """Identical 22 -> 64 -> 64 -> 10 MLP with Linear+ReLU, weighted CE, and Adam in float32."""

    def __init__(
        self,
        n_state: int = N_STATE,
        hidden: int = 64,
        n_actions: int = N_ACTIONS,
        seed: int = 0,
    ) -> None:
        rng = np.random.default_rng(seed)
        dims = [(n_state, hidden), (hidden, hidden), (hidden, n_actions)]
        self.W: list[np.ndarray] = []
        self.b: list[np.ndarray] = []
        for in_d, out_d in dims:
            bound = float(np.sqrt(1.0 / in_d))
            self.W.append(rng.uniform(-bound, bound, size=(out_d, in_d)).astype(np.float32))
            self.b.append(rng.uniform(-bound, bound, size=(out_d,)).astype(np.float32))

    def forward(self, X: np.ndarray) -> np.ndarray:
        a = X.astype(np.float32, copy=False)
        for i in range(len(self.W)):
            a = a @ self.W[i].T + self.b[i]
            if i < len(self.W) - 1:
                a = np.maximum(a, np.float32(0.0))
        return a.astype(np.float32, copy=False)

    def forward_with_cache(self, X: np.ndarray) -> tuple[np.ndarray, list[np.ndarray], list[np.ndarray]]:
        acts: list[np.ndarray] = [X.astype(np.float32, copy=False)]
        pre_acts: list[np.ndarray] = []
        a = acts[0]
        for i in range(len(self.W)):
            z = (a @ self.W[i].T + self.b[i]).astype(np.float32)
            pre_acts.append(z)
            if i < len(self.W) - 1:
                a = np.maximum(z, np.float32(0.0))
            else:
                a = z
            acts.append(a)
        return a, acts, pre_acts

    def loss_and_grads(
        self,
        X: np.ndarray,
        y: np.ndarray,
        class_weights: np.ndarray,
    ) -> tuple[float, list[np.ndarray], list[np.ndarray]]:
        logits, acts, pre_acts = self.forward_with_cache(X)
        shifted = logits - logits.max(axis=1, keepdims=True)
        exp_l = np.exp(shifted)
        probs = exp_l / exp_l.sum(axis=1, keepdims=True)

        n = len(y)
        sample_w = class_weights[y]
        w_sum = float(sample_w.sum()) + 1e-8
        chosen_logp = np.log(np.clip(probs[np.arange(n), y], 1e-12, 1.0))
        loss = float(-(sample_w * chosen_logp).sum() / w_sum)

        dz = probs.copy()
        dz[np.arange(n), y] -= 1.0
        dz = (dz * (sample_w[:, None] / w_sum)).astype(np.float32)

        gW: list[np.ndarray] = [np.zeros_like(w) for w in self.W]
        gb: list[np.ndarray] = [np.zeros_like(b) for b in self.b]
        for i in range(len(self.W) - 1, -1, -1):
            a_prev = acts[i]
            gW[i] = (dz.T @ a_prev).astype(np.float32)
            gb[i] = dz.sum(axis=0).astype(np.float32)
            if i > 0:
                da = dz @ self.W[i]
                dz = (da * (pre_acts[i - 1] > 0.0)).astype(np.float32)

        return loss, gW, gb

    def evaluate_loss(self, X: np.ndarray, y: np.ndarray, class_weights: np.ndarray) -> float:
        logits = self.forward(X)
        shifted = logits - logits.max(axis=1, keepdims=True)
        exp_l = np.exp(shifted)
        probs = exp_l / exp_l.sum(axis=1, keepdims=True)
        n = len(y)
        sample_w = class_weights[y]
        w_sum = float(sample_w.sum()) + 1e-8
        chosen_logp = np.log(np.clip(probs[np.arange(n), y], 1e-12, 1.0))
        return float(-(sample_w * chosen_logp).sum() / w_sum)

    def get_state(self) -> list[tuple[np.ndarray, np.ndarray]]:
        return [(w.copy(), b.copy()) for w, b in zip(self.W, self.b)]

    def set_state(self, state: list[tuple[np.ndarray, np.ndarray]]) -> None:
        self.W = [w.astype(np.float32).copy() for w, _ in state]
        self.b = [b.astype(np.float32).copy() for _, b in state]

    def to_layers_list(self) -> list[dict[str, list]]:
        return [
            {"W": w.astype(np.float32).tolist(), "b": b.astype(np.float32).tolist()}
            for w, b in zip(self.W, self.b)
        ]


def gdscript_forward_single(
    state: Sequence[float] | np.ndarray,
    mean: Sequence[float] | np.ndarray,
    std: Sequence[float] | np.ndarray,
    layers: Sequence[dict[str, Any]],
) -> np.ndarray:
    """Exact reproduction of game/scripts/mlp.gd::forward(state).

    In GDScript, `PackedFloat32Array` stores 32-bit floats while `var s: float`
    accumulates in 64-bit float before storing back into `out[o]` (PackedFloat32Array).
    """
    a = np.empty(len(state), dtype=np.float32)
    for i in range(len(state)):
        a[i] = np.float32((float(state[i]) - float(mean[i])) / float(std[i]))

    for li, layer in enumerate(layers):
        W = layer["W"]
        b = layer["b"]
        out = np.empty(len(b), dtype=np.float32)
        for o in range(len(b)):
            s = float(b[o])
            row = W[o]
            for j in range(len(a)):
                s += float(row[j]) * float(a[j])
            out[o] = np.float32(s)
        if li < len(layers) - 1:
            for o in range(len(out)):
                if out[o] < np.float32(0.0):
                    out[o] = np.float32(0.0)
        a = out
    return a
