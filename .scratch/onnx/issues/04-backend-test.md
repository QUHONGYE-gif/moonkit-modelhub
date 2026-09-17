Status: ready-for-agent

## Parent

`.scratch/onnx/PRD.md`

## What to build

运行官方 ONNX backend test 子集（Gemm/Relu/Softmax/MatMul/Add 的
test_data_set），输入输出 .pb 解析并对照。

## Acceptance criteria

- [x] 至少 3 个官方 case 输出与期望一致

## Blocked by

- `03-ops.md`

## Comments

- 2026-09-17 完成。官方 ONNX backend test 子集 5 个用例全部通过：
  gemm_all_attributes、relu、softmax_axis_1、matmul_2d、add
  （fixture 取自 onnx 1.22 官方数据目录）。
