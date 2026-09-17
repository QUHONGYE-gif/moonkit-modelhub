# 架构与验证策略

## 分层

```
   应用层   cmd/generate（GPT-2 生成 CLI） / cmd/main（modelhub CLI） / examples/*
                                │
   推理层   transformers（GPT-2 前向/生成） ── onnx（图解释执行器）
                                │  共用算子
   内核层   nn（张量 / GEMM / 激活 / 归一化 / 注意力 / KV cache）
                                │
   传输层   modelhub（Hub 客户端 + HF 兼容缓存） ── moonbitlang/async（HTTP/TLS/FS）
```

外部依赖只有两个，都是成熟包：

- `moonbitlang/async`（Apache-2.0）：HTTP、TLS、文件系统、事件循环；
- `howtomakeaname/tokenizers-moonbit`（Apache-2.0）：GPT-2 BPE 分词
  （仅在 `cmd/generate` 与端到端演示中使用，内核与推理层不依赖它）。

## 数据流（端到端生成）

```
repo id ──modelhub──► HF 兼容缓存（blobs / snapshots / refs / trees）
                         │
                         ├─ config.json ──► transformers.parse_config
                         └─ model.safetensors ──► parse_safetensors ──► Gpt2Model::load
prompt ──tokenizers──► token ids ──► Generator（KV cache 增量）──► ids ──decode──► 文本
```

## 三层验证策略

| 层 | 对象 | 参考实现 | 命令 |
|---|---|---|---|
| parity | modelhub 缓存布局与下载行为 | Python `huggingface_hub` 1.31 | `python scripts/parity_test.py`（可用 `PARITY_ENDPOINT` 指向真实端点） |
| golden | nn / transformers / onnx 的算子与语义 | numpy 参考实现（f64） | `python scripts/gen_*_fixture.py` + `moon test` |
| 官方一致性 | ONNX 算子行为 | 官方 backend test 数据 | `moon test onnx/onnx_test.mbt` |

设计原则：

1. **正确性优先于性能**：朴素实现 + 逐元素对照，性能优化等有基准之后再谈
   （见 [BENCHMARK.md](BENCHMARK.md)）；
2. **测试即规格**：每层验证都能一键复现，不依赖人工判断；
3. **真实环境验证**：parity 与端到端演示都会跑真实服务（hf-mirror，含 LFS
   与重定向），本地 mock 只是补充而非唯一依据。

## 目录结构

```
modelhub.mbt / cache.mbt / http_client.mbt / snapshot.mbt / info.mbt   # 顶层：Hub 客户端
nn/           张量与推理内核
transformers/ safetensors + GPT-2
onnx/         protobuf + 图执行器
cmd/main      modelhub CLI
cmd/generate  端到端 GPT-2 生成 CLI
examples/     tensor / onnx / hub 三个示例
bench/        基准程序
scripts/      mock 服务器、fixture 生成、parity / 示例 / 基准脚本
tests/fixtures golden 与官方 backend fixture
docs/         设计与规划文档
```
