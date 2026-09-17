#!/usr/bin/env bash
# 一键运行全部示例（hub 示例使用本地 mock，无需真实网络）。
# 用法：conda run -n moonbit bash scripts/run_examples.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MOON_BIN="${CONDA_PREFIX}/moon/bin/moon"
PORT="${MOCK_PORT:-8765}"

echo "== tensor_demo =="
"$MOON_BIN" run examples/tensor_demo --target native

echo "== onnx_demo =="
"$MOON_BIN" run examples/onnx_demo --target native

echo "== hub_demo (local mock) =="
python3 scripts/mock_hub_server.py >/dev/null 2>&1 &
MOCK_PID=$!
trap 'kill "$MOCK_PID" 2>/dev/null || true' EXIT
sleep 0.5
HF_ENDPOINT="http://127.0.0.1:${PORT}" HF_HUB_CACHE=/tmp/modelhub-hub-demo \
  "$MOON_BIN" run examples/hub_demo --target native

echo "== done =="
