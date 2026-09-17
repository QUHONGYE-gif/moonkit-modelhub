#!/usr/bin/env bash
# 一键运行基准并输出环境信息。
# 用法：conda run -n moonbit bash scripts/bench.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MOON_BIN="${CONDA_PREFIX}/moon/bin/moon"
echo "date: $(date '+%Y-%m-%d %H:%M')"
echo "machine: $(uname -m) / $(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -s)"
echo "toolchain: $("$MOON_BIN" version | head -1)"
echo
"$MOON_BIN" run bench --target native
