Status: ready-for-agent

## Parent

`.scratch/transformers/PRD.md`

## What to build

贪心/温度采样生成：逐步前向 + KV cache 增量；增量结果与全量前向一致。

## Acceptance criteria

- [x] 生成序列 token 均 < vocab_size，遇 EOS 停止
- [x] KV cache 增量 == 全量前向

## Blocked by

- `03-forward.md`

## Comments

- 2026-09-15 完成。贪心/温度采样 + KV cache 增量；贪心序列与 numpy
  逐 token 一致；增量 step logits == 全量前向。
