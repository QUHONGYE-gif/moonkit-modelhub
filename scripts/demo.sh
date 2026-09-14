#!/usr/bin/env bash
# 一键演示：起本地 mock，跑 info / download / snapshot，展示 HF 兼容缓存树。
# 用法：conda run -n moonbit bash scripts/demo.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${MOCK_PORT:-8765}"
CACHE="${DEMO_CACHE:-/tmp/modelhub-demo}"
ENDPOINT="http://127.0.0.1:${PORT}"
MOON_BIN="${CONDA_PREFIX}/moon/bin/moon"

rm -rf "$CACHE"
python3 "$ROOT/scripts/mock_hub_server.py" >/dev/null 2>&1 &
MOCK_PID=$!
trap 'kill "$MOCK_PID" 2>/dev/null || true' EXIT
sleep 0.5

run() {
  "$MOON_BIN" run cmd/main --target native -- "$@"
}

echo "== info =="
run info gpt2 --endpoint "$ENDPOINT" --cache-dir "$CACHE"

echo "== download =="
run download gpt2 config.json --endpoint "$ENDPOINT" --cache-dir "$CACHE"

echo "== snapshot (exclude *.bin) =="
run snapshot gpt2 --endpoint "$ENDPOINT" --cache-dir "$CACHE" --exclude '*.bin'

echo "== cache tree =="
find "$CACHE" \( -type f -o -type l \) | sort
