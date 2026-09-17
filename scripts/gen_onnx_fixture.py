#!/usr/bin/env python3
"""Generate ONNX fixtures for onnx.mbt: a small mixed-op model plus manifests.

Usage: conda run -n moonbit python scripts/gen_onnx_fixture.py
"""

import json
import os

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "fixtures", "onnx")

rng = np.random.default_rng(7)

X = rng.standard_normal((2, 4)).astype("float32")
W0 = rng.standard_normal((4, 6)).astype("float32")
b0 = rng.standard_normal(6).astype("float32")
W1 = rng.standard_normal((6, 3)).astype("float32")
AddB = rng.standard_normal((2, 3)).astype("float32")

nodes = [
    helper.make_node("Gemm", ["X", "W0", "b0"], ["Y"], alpha=1.0, beta=1.0),
    helper.make_node("Relu", ["Y"], ["R"]),
    helper.make_node("MatMul", ["R", "W1"], ["M"]),
    helper.make_node("Add", ["M", "AddB"], ["S"]),
    helper.make_node("Transpose", ["S"], ["T"], perm=[1, 0]),
    helper.make_node("Reshape", ["T", "shape_c"], ["Re"]),
    helper.make_node("Softmax", ["Re"], ["P"], axis=1),
    helper.make_node("Concat", ["P", "P"], ["C"], axis=0),
    helper.make_node("Tanh", ["C"], ["T2"]),
    helper.make_node("Flatten", ["T2"], ["F"], axis=1),
    helper.make_node("Sigmoid", ["F"], ["O"]),
]

initializers = [
    numpy_helper.from_array(W0, name="W0"),
    numpy_helper.from_array(b0, name="b0"),
    numpy_helper.from_array(W1, name="W1"),
    numpy_helper.from_array(AddB, name="AddB"),
    numpy_helper.from_array(np.array([3, 2], dtype=np.int64), name="shape_c"),
]

graph = helper.make_graph(
    nodes,
    "mixed",
    [helper.make_tensor_value_info("X", TensorProto.FLOAT, [2, 4])],
    [helper.make_tensor_value_info("O", TensorProto.FLOAT, [4, 2])],
    initializer=initializers,
)
model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 13)])
model.ir_version = 8

os.makedirs(OUT, exist_ok=True)
onnx.save(model, os.path.join(OUT, "model.onnx"))


def flat(x):
    return [float(v) for v in np.asarray(x).ravel()]


manifest = {
    "ir_version": model.ir_version,
    "opset": 13,
    "nodes": [
        {
            "op_type": n.op_type,
            "inputs": list(n.input),
            "outputs": list(n.output),
            "attrs": {
                a.name: {
                    "kind": helper.get_attribute_value(a).__class__.__name__,
                    "value": (
                        helper.get_attribute_value(a).tolist()
                        if isinstance(helper.get_attribute_value(a), np.ndarray)
                        else helper.get_attribute_value(a)
                    ),
                }
                for a in n.attribute
            },
        }
        for n in nodes
    ],
    "initializers": [
        {
            "name": t.name,
            "shape": list(t.dims),
            "data": [float(v) for v in numpy_helper.to_array(t).ravel()[:4]],
        }
        for t in initializers
    ],
}
with open(os.path.join(OUT, "manifest.json"), "w") as f:
    json.dump(manifest, f)


def softmax(x, axis):
    x = x - x.max(axis=axis, keepdims=True)
    e = np.exp(x)
    return e / e.sum(axis=axis, keepdims=True)


Y = X @ W0 + b0
R = np.maximum(Y, 0)
M = R @ W1
S = M + AddB
T = S.transpose(1, 0)
Re = T.reshape(3, 2)
P = softmax(Re, axis=1)
C = np.concatenate([P, P], axis=0)
T2 = np.tanh(C)
F = T2.reshape(6, 2)
O = 1.0 / (1.0 + np.exp(-F))

intermediates = {
    "Y": Y,
    "R": R,
    "M": M,
    "S": S,
    "T": T,
    "Re": Re,
    "P": P,
    "C": C,
    "T2": T2,
    "F": F,
    "O": O,
}

with open(os.path.join(OUT, "expected_outputs.json"), "w") as f:
    json.dump(
        {
            "output": "O",
            "input": {"name": "X", "shape": [2, 4], "data": flat(X)},
            "shape": [6, 2],
            "expected": flat(O),
            "intermediates": {
                name: {"shape": list(np.asarray(v).shape), "data": flat(v)}
                for name, v in intermediates.items()
            },
        },
        f,
    )

print("onnx fixtures written to", OUT)
