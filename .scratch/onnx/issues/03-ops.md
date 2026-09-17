Status: ready-for-agent

## Parent

`.scratch/onnx/PRD.md`

## What to build

算子集 v1：Gemm/MatMul/Add/Relu/Sigmoid/Tanh/Softmax/Reshape/Flatten/
Transpose/Concat；numpy 参考生成 golden。

## Acceptance criteria

- [x] 全部算子通过 golden 测试
- [x] Gemm 的 alpha/beta/transA/transB 属性生效

## Blocked by

- `02-executor.md`

## Comments

- 2026-09-17 完成。Gemm/MatMul/Add/Relu/Sigmoid/Tanh/Softmax(任意 axis)/
  Reshape/Flatten/Transpose/Concat，numpy 参考逐中间量 golden 通过；
  Gemm 四属性生效（官方 gemm_all_attributes 用例覆盖）。
