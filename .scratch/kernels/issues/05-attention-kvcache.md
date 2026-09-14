Status: ready-for-agent

## Parent

`.scratch/kernels/PRD.md`

## What to build

scaled dot-product attention（causal mask）、多头、KV cache 增量。
golden 对照 numpy 手写参考实现；增量缓存结果与一次全量前向一致。

## Acceptance criteria

- [ ] 单头/多头 attention 通过 golden 测试
- [ ] causal mask 生效（未来位置为零概率）
- [ ] KV cache 增量 == 全量前向

## Blocked by

- `02-tensor-core.md`
- `03-gemm.md`
- `04-activations-norms.md`
