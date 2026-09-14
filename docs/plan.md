# modelhub 项目规划

> 2026 MoonBit 九月黑客松参赛项目
>
> 本期验收截止：2026-09-24（同时截止报名）

## 背景与目标

做一个纯 MoonBit 的 HuggingFace Hub 客户端库：让 MoonBit 程序能以
`snapshot_download("gpt2")` 的方式从 HuggingFace 拉取模型、权重与配置文件，
并以与 Python `huggingface_hub` 完全一致的布局写入本地缓存。

赛事要求复盘（验收标准）：

- MoonBit 为主要实现语言 ✅（纯 MoonBit，无 FFI）
- 公开仓库、连续可追踪的提交记录
- 清晰 README、可运行示例、必要测试
- 认可的开源许可证 ✅（Apache-2.0）
- AI 可解释：AI 辅助开发，技术选择与质量由参赛者掌握

## 定位与差异化

| 已有项目 | 覆盖范围 | 我们的差异化 |
|---|---|---|
| tokenizers-moonbit 的 `hub` 子包 | 只能下载 tokenizer.json | 通用的模型/数据集仓库下载 |
| huggingface_hub (Python) | 全功能 | MoonBit 语言、无 Python 运行时依赖 |
| ds4 / mbtorch | 推理、张量 | 我们只做分发/缓存这一层，互为依赖而非竞争 |

## MVP 范围（v0.1.0，9/24 验收）

1. `hf_hub_download(repo_id, filename, revision?, cache_dir?, ...)`
   - 单文件下载；etag / commit hash 校验；断点续传；命中缓存时零网络请求
2. `snapshot_download(repo_id, revision?, allow_patterns?, ignore_patterns?)`
   - 解析 `api/models/<repo>/revision/<rev>`，批量下载快照
3. 缓存布局与 `huggingface_hub` 完全一致：
   - `models--<repo>/blobs/<etag>`（去重存储）
   - `models--<repo>/snapshots/<commit>/...`（符号链接布局）
   - `models--<repo>/refs/<revision>`（revision → commit 映射）
4. 认证：`HF_TOKEN` / `HUGGING_FACE_HUB_TOKEN` 环境变量与 token 文件
5. 端点与环境变量：`HF_ENDPOINT`（镜像，如 hf-mirror.com）、`HF_HUB_OFFLINE`
6. API 信息端点：`model_info` / `dataset_info`（含 siblings 文件列表）
7. CLI：`modelhub download gpt2 config.json` / `modelhub snapshot gpt2`
8. 错误语义对齐：`GatedRepo`、`RevisionNotFound`、`EntryNotFound`

## 非目标（本期明确不做）

- 上传（`upload_folder` / `create_repo`）、LFS 上传、数据集查看器、Inference API
- 并行分片下载、进度条渲染（可后续版本）
- transformers / onnx 推理本身（见下方候选池）

## 大阶段划分（2026-09-14 → 09-24）

| 阶段 | 时间 | 目标 | 产出 |
|---|---|---|---|
| 阶段 0 · 工程准备 | 09-14（已完成） | 环境、仓库骨架、技能配置 | conda 环境、moon 脚手架、docs/agents |
| 阶段 1 · 技术验证与核心下载 | 09-15 → 09-17 | HTTP/TLS 选型 + `hf_hub_download` + 缓存布局 | 见 `.scratch/core-download/issues/` |
| 阶段 2 · 快照与接入配置 | 09-18 → 09-19 | `snapshot_download`、认证、离线/镜像 | 见 `.scratch/snapshot-config/issues/` |
| 阶段 3 · 平台集成与 CLI | 09-20 → 09-21 | API 端点、CLI、错误语义 | 见 `.scratch/platform-cli/issues/` |
| 阶段 4 · parity 质量与交付 | 09-22 → 09-24 | parity 套件、文档、演示、验收提交 | 见 `.scratch/quality-release/issues/` |
| 阶段 5 · 候选池 | 本期之后 | transformers.mbt / onnx.mbt | 复用 modelhub 作为地基 |

每个阶段独立验收：前一阶段的产出必须能单独演示或验证，再进入下一阶段。
阶段 1 是唯一存在技术不确定项（HTTP/TLS）的阶段，因此最先展开为 issues。

## 风险与对策

1. **HTTP/TLS 是最大不确定项**。MoonBit 的 `moonbitlang/async` 提供 HTTP/socket，
   但 native 端 TLS 能力需要 spike 验证。对策：第一天就做最小 HTTPS GET 实验；
   备选方案是 js 后端经 fetch、native 端经 libcurl FFI（会牺牲"无 FFI"卖点，作为兜底）。
2. **符号链接缓存布局在 Windows/部分文件系统不可用**。对策：与官方一致，优先符号链接，
   失败时退回拷贝文件并保持行为可配置。
3. **时间紧张**。MVP 每一条都对应可独立演示的小功能，任何时刻都可以交付当前已完成部分，
   避免"全有或全无"。

## 候选池（本期之后 / 有余力再做）

- `transformers.mbt`：纯 MoonBit 的微型 transformers（GPT-2 级推理 + 生成），
  复用本项目的 `from_pretrained` 与 tokenizers-moonbit。
- `onnx.mbt`：通用 ONNX 图解释执行器（差异化于 mbtorch 的模式匹配导入器）。

两者都依赖 modelhub 完成「模型获取」这第一步，因此本项目的产出是它们的直接地基。
