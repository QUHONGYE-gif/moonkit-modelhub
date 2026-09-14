Status: ready-for-human

## Parent

`.scratch/kernels/PRD.md`

## What to build

确认内核底座选型（自研 vs 复用 moon-tensor/mbtorch），把决策与数值类型约定
写入 `docs/design.md`（新增「推理内核」章节），并搭好 `nn/` 子包骨架
（moon.pkg、空模块、示例测试）。

## Acceptance criteria

- [ ] 选型结论文档化（含 moon-tensor/mbtorch 现状摘要）
- [ ] `nn/` 子包可编译，`moon check --target native` 通过

## Blocked by

None - can start immediately
