Status: ready-for-agent

## Parent

`.scratch/kernels/PRD.md`

## What to build

matmul（单/批量，朴素三重循环），随机形状 golden diff < 1e-4；
记录一次小规模 benchmark 结果到 issue 评论。

## Acceptance criteria

- [ ] 单/批量 matmul 通过 numpy golden 测试
- [ ] 形状不兼容时抛错

## Blocked by

- `02-tensor-core.md`
