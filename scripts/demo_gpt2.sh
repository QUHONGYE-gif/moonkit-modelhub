#!/usr/bin/env bash
# 端到端演示：modelhub 拉模型 → tokenizers-moonbit 分词 → GPT-2 生成。
# 用法：conda run -n moonbit bash scripts/demo_gpt2.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
CACHE="${DEMO_CACHE:-/tmp/modelhub-gpt2}"
MOON_BIN="${CONDA_PREFIX}/moon/bin/moon"

"$MOON_BIN" run cmd/generate --target native -- \
  --endpoint "$ENDPOINT" \
  --cache-dir "$CACHE" \
  --prompt "The quick brown fox" \
  --max-new 20
