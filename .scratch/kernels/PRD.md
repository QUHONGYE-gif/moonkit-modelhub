# PRD: 阶段 5 · 张量与推理内核（moonkit/nn）

## 背景

生态栈的「推理」半边从这里开始。`moonkit/nn` 是 transformers.mbt 与
onnx.mbt 共用的推理内核：Float 张量 + 核心算子，正确性优先，
全部用 Python numpy 生成 golden 数据逐元素对照。

相关文档：[docs/plan.md](../../docs/plan.md)。

## 范围（本期）

- Tensor 核心（shape/data/行主序、reshape/transpose/view、seeded randn）
- 逐元素运算（add/sub/mul/scale）
- GEMM（单/批量，朴素实现）
- gelu / softmax / LayerNorm / RMSNorm
- scaled dot-product attention（causal mask、多头、KV cache 增量）

## 决策记录

- 数值类型 MVP 用 Float(f64)：与 numpy 默认 double 直接对照、省去 f32 舍入
  噪音；f32 化留到 transformers.mbt 阶段按需切换。
- 自研朴素实现，moon-tensor 仅作参考基准；性能优化（分块/并行）不在本期。

## 非范围

- 自动微分、训练、量化、GPU

## 验收

issues/ 下 5 个 issue 全部完成，`moon test --target native` 全绿，
golden fixture 由 `scripts/gen_nn_golden.py`（numpy）生成并可复现。
