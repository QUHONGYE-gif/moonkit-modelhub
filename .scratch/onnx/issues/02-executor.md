Status: ready-for-agent

## Parent

`.scratch/onnx/PRD.md`

## What to build

图执行器：按数据依赖拓扑排序，张量注册表（初始器 + 中间结果），
未知 op 或缺失输入时明确报错。

## Acceptance criteria

- [x] 顺序图（MLP 直路）端到端执行出结果
- [x] 缺失输入/未知算子报错而非崩溃

## Blocked by

- `01-protobuf.md`

## Comments

- 2026-09-17 完成。`run_model`：初始器+输入进注册表，按依赖反复调度直到收敛；
  未知算子/未解析输入抛 `OnnxError::Parse`。
