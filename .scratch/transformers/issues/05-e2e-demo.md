Status: ready-for-agent

## Parent

`.scratch/transformers/PRD.md`

## What to build

端到端演示：modelhub 拉 hf-internal-testing/tiny-random-gpt2 →
tokenizers-moonbit 编码 prompt → GPT-2 生成 → 解码输出；`scripts/demo_gpt2.sh`。

## Acceptance criteria

- [x] 对真实仓库一键跑通，输出可解码文本

## Blocked by

- `04-generation.md`

## Comments

- 2026-09-15 完成。`cmd/generate` + `scripts/demo_gpt2.sh` 对
  hf-internal-testing/tiny-random-gpt2 一键跑通：modelhub 拉取（含镜像
  308 到 huggingface.co 的自动重试）→ safetensors 加载 → tokenizers-moonbit
  分词 → 生成 → 解码。随机权重模型输出为可解码文本（重复 token 属预期）。
