Status: ready-for-agent

## Parent

`.scratch/release/PRD.md`

## What to build

`bench/` 可执行基准：matmul（128/256）、attention、GPT-2 前向、ONNX 图执行；
结果写入 docs/BENCHMARK.md（可复现命令 + 数字）。

## Acceptance criteria

- [x] `bash scripts/bench.sh` 输出各基准耗时
- [x] docs/BENCHMARK.md 记录环境与数字

## Blocked by

- `01-examples.md`

## Comments

- 2026-09-17 完成。matmul 128/256、attention、GPT-2 前向、ONNX 图执行；
  M1 上 matmul 128³ 26.8ms、256³ 210.5ms（朴素实现），其余数字见
  docs/BENCHMARK.md。
