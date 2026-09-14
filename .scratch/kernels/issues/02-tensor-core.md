Status: ready-for-agent

## Parent

`.scratch/kernels/PRD.md`

## What to build

Tensor 核心：构造（含大小校验）、zeros、seeded randn、reshape/transpose/view、
逐元素 add/sub/mul/scale。golden 数据由 numpy 生成，MoonBit 测试逐元素对照
（容差 1e-5）。

## Acceptance criteria

- [ ] 全部运算通过 numpy golden 测试
- [ ] reshape 大小不匹配抛错；越界访问行为明确

## Blocked by

- `01-kernel-foundation-decision.md`
