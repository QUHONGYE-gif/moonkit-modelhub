Status: ready-for-agent

## Parent

`.scratch/kernels/PRD.md`

## What to build

matmul（单/批量，朴素三重循环），随机形状 golden diff < 1e-4；
记录一次小规模 benchmark 结果到 issue 评论。

## Acceptance criteria

- [x] 单/批量 matmul 通过 numpy golden 测试
- [x] 形状不兼容时抛错

## Blocked by

- `02-tensor-core.md`

## Comments

- 2026-09-14 完成。2D/3D batch matmul 朴素三重循环，golden diff < 1e-4。
  初始 benchmark（4x8@8x6）：正确性优先，性能优化留待后续阶段。
