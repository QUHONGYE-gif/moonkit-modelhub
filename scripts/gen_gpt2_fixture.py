#!/usr/bin/env python3
"""Generate a tiny GPT-2 fixture: safetensors weights, config, expected logits
and expected greedy generation (numpy reference, computed in float64).

Usage: conda run -n moonbit python scripts/gen_gpt2_fixture.py
"""

import json
import os

import numpy as np
from safetensors.numpy import save_file

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "fixtures", "gpt2-model")

cfg = {
    "vocab_size": 16,
    "n_ctx": 32,
    "n_embd": 8,
    "n_head": 2,
    "n_layer": 2,
    "intermediate_size": 16,
    "layer_norm_epsilon": 1e-5,
    "bos_token_id": 1,
    "eos_token_id": 1,
}

V, C, H, L, I = (
    cfg["vocab_size"],
    cfg["n_ctx"],
    cfg["n_head"],
    cfg["n_layer"],
    cfg["intermediate_size"],
)
D = cfg["n_embd"]

rng = np.random.default_rng(42)
weights = {}
weights["transformer.wte.weight"] = rng.standard_normal((V, D)).astype("float32")
weights["transformer.wpe.weight"] = rng.standard_normal((C, D)).astype("float32")
for i in range(L):
    p = f"transformer.h.{i}"
    weights[f"{p}.ln_1.weight"] = rng.standard_normal(D).astype("float32")
    weights[f"{p}.ln_1.bias"] = rng.standard_normal(D).astype("float32")
    weights[f"{p}.attn.c_attn.weight"] = rng.standard_normal((3 * D, D)).astype("float32")
    weights[f"{p}.attn.c_attn.bias"] = rng.standard_normal(3 * D).astype("float32")
    weights[f"{p}.attn.c_proj.weight"] = rng.standard_normal((D, D)).astype("float32")
    weights[f"{p}.attn.c_proj.bias"] = rng.standard_normal(D).astype("float32")
    weights[f"{p}.ln_2.weight"] = rng.standard_normal(D).astype("float32")
    weights[f"{p}.ln_2.bias"] = rng.standard_normal(D).astype("float32")
    weights[f"{p}.mlp.c_fc.weight"] = rng.standard_normal((I, D)).astype("float32")
    weights[f"{p}.mlp.c_fc.bias"] = rng.standard_normal(I).astype("float32")
    weights[f"{p}.mlp.c_proj.weight"] = rng.standard_normal((D, I)).astype("float32")
    weights[f"{p}.mlp.c_proj.bias"] = rng.standard_normal(D).astype("float32")
weights["transformer.ln_f.weight"] = rng.standard_normal(D).astype("float32")
weights["transformer.ln_f.bias"] = rng.standard_normal(D).astype("float32")

os.makedirs(OUT, exist_ok=True)
save_file(weights, os.path.join(OUT, "model.safetensors"))
with open(os.path.join(OUT, "config.json"), "w") as f:
    json.dump(cfg, f)

# float64 reference（与 MoonBit Double 一致）
w = {k: v.astype(np.float64) for k, v in weights.items()}


def layernorm(x, ww, bb, eps):
    mean = x.mean(-1, keepdims=True)
    var = ((x - mean) ** 2).mean(-1, keepdims=True)
    return (x - mean) / np.sqrt(var + eps) * ww + bb


def gelu(x):
    return 0.5 * x * (1.0 + np.tanh(np.sqrt(2 / np.pi) * (x + 0.044715 * x**3)))


def softmax(x):
    x = x - x.max(-1, keepdims=True)
    e = np.exp(x)
    return e / e.sum(-1, keepdims=True)


def forward(ids):
    ids = np.asarray(ids, dtype=np.int64)
    t = len(ids)
    x = w["transformer.wte.weight"][ids] + w["transformer.wpe.weight"][:t]  # [t, D]
    for i in range(L):
        p = f"transformer.h.{i}"
        h = layernorm(x, w[f"{p}.ln_1.weight"], w[f"{p}.ln_1.bias"], cfg["layer_norm_epsilon"])
        qkv = h @ w[f"{p}.attn.c_attn.weight"].T + w[f"{p}.attn.c_attn.bias"]  # [t, 3D]
        q, k, v = np.split(qkv, 3, axis=-1)  # each [t, D]
        dh = D // H

        def heads(z):
            return z.reshape(t, H, dh).transpose(1, 0, 2)  # [H, t, dh]

        q, k, v = heads(q), heads(k), heads(v)
        scores = q @ k.transpose(0, 2, 1) / np.sqrt(dh)
        scores = np.where(np.triu(np.ones((t, t), bool), 1), -1e300, scores)
        attn = (softmax(scores) @ v).transpose(1, 0, 2).reshape(t, D)
        x = x + attn @ w[f"{p}.attn.c_proj.weight"].T + w[f"{p}.attn.c_proj.bias"]
        h = layernorm(x, w[f"{p}.ln_2.weight"], w[f"{p}.ln_2.bias"], cfg["layer_norm_epsilon"])
        m = gelu(h @ w[f"{p}.mlp.c_fc.weight"].T + w[f"{p}.mlp.c_fc.bias"])
        x = x + m @ w[f"{p}.mlp.c_proj.weight"].T + w[f"{p}.mlp.c_proj.bias"]
    x = layernorm(x, w["transformer.ln_f.weight"], w["transformer.ln_f.bias"], cfg["layer_norm_epsilon"])
    return x @ w["transformer.wte.weight"].T  # [t, V]


logits = forward([1, 2, 3, 4])
with open(os.path.join(OUT, "expected_logits.json"), "w") as f:
    json.dump(
        {"input_ids": [1, 2, 3, 4], "expected": logits.ravel().tolist()},
        f,
    )

cur = [1, 2]
for _ in range(5):
    nxt = int(np.argmax(forward(cur)[-1]))
    if nxt == cfg["eos_token_id"]:
        break
    cur.append(nxt)
with open(os.path.join(OUT, "expected_generation.json"), "w") as f:
    json.dump({"input_ids": [1, 2], "expected": cur}, f)

probe = {
    "wte_00": float(weights["transformer.wte.weight"][0, 0]),
    "wte_last": float(weights["transformer.wte.weight"][V - 1, D - 1]),
    "ln1_0": float(weights["transformer.h.0.ln_1.weight"][0]),
}
with open(os.path.join(OUT, "weight_probe.json"), "w") as f:
    json.dump(probe, f)

print("gpt2 fixtures written to", OUT)
