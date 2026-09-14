# modelhub

MoonBit 的 HuggingFace Hub 客户端库（`moonkit/modelhub`）。用纯 MoonBit 实现与 Python
`huggingface_hub` 兼容的模型仓库下载、修订版本解析与缓存管理，让 MoonBit 程序可以用
`snapshot_download("gpt2")` 直接接入 HuggingFace 生态。

## 目标

- **缓存 parity**：本地缓存目录结构与 `huggingface_hub` 完全一致
  （`blobs/<etag>`、`snapshots/<commit>/`、`refs/`），双方可互认、可共用。
- **行为 parity**：revision 解析、断点续传、离线模式、gated repo 错误语义与官方客户端对齐。
- **全后端**：native / wasm / js 后端可用，无原生运行时依赖。

## 为什么做这个

MoonBit 已有 tokenizers-moonbit（附带一个只能下载 tokenizer.json 的 mini hub），
但缺少通用的 Hub 客户端。它是 transformers / onnx 推理等上层项目共同的地基依赖，
也是 MoonBit 接入 HuggingFace 生态的入口。

## 状态

早期开发，2026 MoonBit 九月黑客松参赛项目。路线图见 [docs/plan.md](docs/plan.md)，
API 草案见 [docs/design.md](docs/design.md)。

## 开发环境

MoonBit 工具链与 Python 测试依赖都隔离在 conda 环境 `moonbit` 中：

```bash
conda activate moonbit      # 激活后 moon 可用
moon test                   # 默认 wasm 后端
moon test --target native
```

parity 测试依赖安装：`pip install huggingface_hub`（在 `moonbit` 环境内）。

## 许可证

Apache-2.0
