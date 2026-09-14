Status: ready-for-agent

## Parent

`.scratch/kernels/PRD.md`

## What to build

gelu（tanh 近似，GPT-2 同款）、数值稳定 softmax（指定维）、
LayerNorm 与 RMSNorm。numpy 对照 golden 测试。

## Acceptance criteria

- [x] gelu/softmax/layernorm/rmsnorm 通过 golden 测试
- [x] softmax 大数值输入不溢出（稳定性用例）

## Blocked by

- `02-tensor-core.md`

## Comments

- 2026-09-14 完成。gelu(tanh 近似)/softmax(max 减除)/LayerNorm/RMSNorm
  全部通过 numpy golden；softmax 含 1000.0 级稳定性用例。
