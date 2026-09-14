#!/usr/bin/env python3
"""Generate golden fixtures for moonkit/nn using numpy as reference.

Usage: conda run -n moonbit python scripts/gen_nn_golden.py
"""

import json
import os

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "fixtures", "nn")


def write(name, obj):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(obj, f)


def flat(x):
    return [float(v) for v in np.asarray(x).ravel()]


def gelu_tanh(x):
    return 0.5 * x * (1.0 + np.tanh(np.sqrt(2 / np.pi) * (x + 0.044715 * x**3)))


def softmax(x):
    x = x - x.max(axis=-1, keepdims=True)
    e = np.exp(x)
    return e / e.sum(axis=-1, keepdims=True)


def layernorm(x, w, b, eps=1e-5):
    mean = x.mean(axis=-1, keepdims=True)
    var = ((x - mean) ** 2).mean(axis=-1, keepdims=True)
    return (x - mean) / np.sqrt(var + eps) * w + b


def rmsnorm(x, w, eps=1e-5):
    ms = (x**2).mean(axis=-1, keepdims=True)
    return x / np.sqrt(ms + eps) * w


def attention(q, k, v, causal, d):
    scale = 1.0 / np.sqrt(d)
    scores = (q @ k.transpose(0, 2, 1)) * scale
    if causal:
        tq, tk = q.shape[1], k.shape[1]
        mask = np.triu(np.ones((tq, tk), dtype=bool), k=1)
        scores = np.where(mask, -1e300, scores)
    return softmax(scores) @ v


rng = np.random.default_rng(42)

a = rng.standard_normal((2, 3))
b = rng.standard_normal((2, 3))
write("reshape", {
    "shape": [2, 3], "data": flat(a), "new_shape": [3, 2],
    "expected_shape": [3, 2], "expected": flat(a.reshape(3, 2)),
})
write("transpose", {
    "shape": [2, 3], "data": flat(a),
    "expected_shape": [3, 2], "expected": flat(a.T),
})
write("add", {"shape": [2, 3], "a": flat(a), "b": flat(b), "expected": flat(a + b)})
write("sub", {"shape": [2, 3], "a": flat(a), "b": flat(b), "expected": flat(a - b)})
write("mul", {"shape": [2, 3], "a": flat(a), "b": flat(b), "expected": flat(a * b)})
write("scale", {"shape": [2, 3], "data": flat(a), "s": 2.5, "expected": flat(a * 2.5)})

m1 = rng.standard_normal((4, 8))
m2 = rng.standard_normal((8, 6))
write("gemm", {
    "a_shape": [4, 8], "a": flat(m1), "b_shape": [8, 6], "b": flat(m2),
    "expected_shape": [4, 6], "expected": flat(m1 @ m2),
})
mb1 = rng.standard_normal((2, 3, 4))
mb2 = rng.standard_normal((2, 4, 5))
write("gemm_batch", {
    "a_shape": [2, 3, 4], "a": flat(mb1), "b_shape": [2, 4, 5], "b": flat(mb2),
    "expected_shape": [2, 3, 5], "expected": flat(mb1 @ mb2),
})

x = np.linspace(-3.0, 3.0, 13)
write("gelu", {"shape": [13], "data": flat(x), "expected": flat(gelu_tanh(x))})

s = np.array([[1.0, 2.0, 3.0], [1000.0, 1000.0, 1000.0], [-1.0, 0.0, 1.0]])
write("softmax", {"shape": [3, 3], "data": flat(s), "expected": flat(softmax(s))})

ln_x = rng.standard_normal((2, 4))
ln_w = rng.standard_normal((4,))
ln_b = rng.standard_normal((4,))
write("layernorm", {
    "shape": [2, 4], "data": flat(ln_x), "weight": flat(ln_w), "bias": flat(ln_b),
    "eps": 1e-5, "expected": flat(layernorm(ln_x, ln_w, ln_b)),
})
rms_x = rng.standard_normal((2, 4))
rms_w = rng.standard_normal((4,))
write("rmsnorm", {
    "shape": [2, 4], "data": flat(rms_x), "weight": flat(rms_w),
    "eps": 1e-5, "expected": flat(rmsnorm(rms_x, rms_w)),
})

B, TQ, TK, D = 2, 4, 6, 8
q = rng.standard_normal((B, TQ, D))
k = rng.standard_normal((B, TK, D))
v = rng.standard_normal((B, TK, D))
write("attention", {
    "b": B, "tq": TQ, "tk": TK, "d": D,
    "q": flat(q), "k": flat(k), "v": flat(v), "causal": False,
    "expected_shape": [B, TQ, D],
    "expected": flat(attention(q, k, v, False, D)),
})
write("attention_causal", {
    "b": B, "tq": TQ, "tk": TK, "d": D,
    "q": flat(q), "k": flat(k), "v": flat(v), "causal": True,
    "expected_shape": [B, TQ, D],
    "expected": flat(attention(q, k, v, True, D)),
})

k1, k2 = k[:, :3, :], k[:, 3:, :]
v1, v2 = v[:, :3, :], v[:, 3:, :]
q2 = rng.standard_normal((B, 3, D))
write("kv_cache", {
    "b": B, "tq2": 3, "d": D,
    "q2": flat(q2), "k1": flat(k1), "v1": flat(v1),
    "k2": flat(k2), "v2": flat(v2),
    "expected_shape": [B, 3, D],
    "expected": flat(attention(q2, k, v, True, D)),
})

print("golden fixtures written to", OUT)
