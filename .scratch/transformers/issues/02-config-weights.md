Status: ready-for-agent

## Parent

`.scratch/transformers/PRD.md`

## What to build

GPT-2 config.json 解析（n_layer/n_head/n_embd/intermediate/vocab/n_ctx/eps）；
权重映射（wte/wpe/h.N.*/ln_f/lm_head），attn/mlp bias 可选（按张量存在与否）。

## Acceptance criteria

- [x] 无 bias 与有 bias 两种权重布局都能加载
- [x] 缺失必需张量时报错

## Blocked by

- `01-safetensors.md`

## Comments

- 2026-09-15 完成。config.json 解析 + 权重映射；bias 可选；
  Conv1D（[in,out]）与 Linear（[out,in]）两种权重布局自动识别
  （以 c_attn 形状判定）；lm_head 缺失时与 wte 绑定。
