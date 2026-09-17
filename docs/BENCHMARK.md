# Benchmarks

朴素实现（正确性优先）的参考数字，用于观察量级而非性能承诺。

## 环境

- 机器：Apple M1 (arm64)
- 工具链：moon 0.1.20260904
- 后端：native（debug 构建）
- 复现：`conda run -n moonbit bash scripts/bench.sh`

## 结果（2026-09-17，best of 3）

| 基准 | 耗时 |
|---|---|
| matmul 128×128 | 26.8 ms |
| matmul 256×256 | 210.5 ms |
| attention [2, 64, 64] causal | 15.4 ms |
| GPT-2 forward（2 层，8 tokens，fixture 模型） | 0.55 ms |
| ONNX 图执行（10 节点，fixture 模型） | 0.012 ms |

## 说明

- 矩阵乘法是朴素三重循环，没有分块、SIMD 或 BLAS 集成——与 BLAS 相比慢一到
  两个数量级属预期，当前目标是正确性（numpy golden 对照）。
- GPT-2 与 ONNX 的数字基于仓库内的小型 fixture 模型（2 层 / 10 节点），
  用于观察框架开销，不代表真实模型吞吐。
- 性能优化（分块、f32、SIMD、并行）在路线图中，属于后续阶段。
