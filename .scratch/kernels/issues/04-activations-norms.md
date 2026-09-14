Status: ready-for-agent

## Parent

`.scratch/kernels/PRD.md`

## What to build

gelu（tanh 近似，GPT-2 同款）、数值稳定 softmax（指定维）、
LayerNorm 与 RMSNorm。numpy 对照 golden 测试。

## Acceptance criteria

- [ ] gelu/softmax/layernorm/rmsnorm 通过 golden 测试
- [ ] softmax 大数值输入不溢出（稳定性用例）

## Blocked by

- `02-tensor-core.md`
