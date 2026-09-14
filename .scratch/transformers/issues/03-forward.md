Status: ready-for-agent

## Parent

`.scratch/transformers/PRD.md`

## What to build

GPT-2 前向：wte+wpe → N×(LN→attn→残差→LN→MLP→残差) → ln_f → lm_head。
numpy 参考实现生成 golden logits 对照。

## Acceptance criteria

- [x] logits 与 numpy 参考一致（1e-4）
- [x] 多头注意力、gelu_new、tied lm_head 语义正确

## Blocked by

- `02-config-weights.md`

## Comments

- 2026-09-15 完成。GPT-2 前向（wte+wpe → blocks → ln_f → lm_head），
  numpy 参考 logits 逐元素一致；增量 step 与全量前向一致（测试覆盖）。
