Status: ready-for-agent

## Parent

`.scratch/kernels/PRD.md`

## What to build

scaled dot-product attention（causal mask）、多头、KV cache 增量。
golden 对照 numpy 手写参考实现；增量缓存结果与一次全量前向一致。

## Acceptance criteria

- [x] 单头/多头 attention 通过 golden 测试
- [x] causal mask 生效（未来位置为零概率）
- [x] KV cache 增量 == 全量前向

## Blocked by

- `02-tensor-core.md`
- `03-gemm.md`
- `04-activations-norms.md`

## Comments

- 2026-09-14 完成。attention（causal mask、多头拆分）、cat_seq（KV cache）
  通过 numpy golden；增量拼接结果与全量前向一致。
