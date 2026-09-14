# PRD: 阶段 6 · transformers.mbt（GPT-2 推理）

## 背景

在 `moonkit/nn` 内核上搭 GPT-2 推理：safetensors 权重加载、GPT-2 前向、
KV cache 采样生成，配合 modelhub 拉模型、tokenizers-moonbit 分词，
完成「拉模型 → 跑推理 → 生成文本」闭环。

对应 GitHub issue #7。相关文档：[docs/plan.md](../../docs/plan.md)。

## 范围（本期）

- safetensors 解析（F32 LE；header JSON + data buffer）
- GPT-2 config.json 解析与权重映射（可选 bias）
- GPT-2 前向（embeddings / transformer blocks / ln_f / lm_head）
- 生成：greedy + temperature、KV cache 增量
- E2E：modelhub 拉 hf-internal-testing/tiny-random-gpt2（含 model.safetensors）
  → tokenizers-moonbit 分词 → 生成 → 解码

## 非范围

- 训练、LoRA、量化、其他架构（BERT/Llama）

## 验收

issues/ 下 5 个 issue 全部完成；前向与生成通过 numpy 参考 golden；
E2E 演示脚本跑通。
