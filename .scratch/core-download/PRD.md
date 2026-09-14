# PRD: 阶段 1 · 技术验证与核心下载

## 背景

modelhub 是 MoonBit 的 HuggingFace Hub 客户端库，目标是与 Python `huggingface_hub`
在缓存布局与下载行为上达成 parity。阶段 1 是整个项目唯一存在技术不确定项
（HTTP/TLS 选型）的阶段，验证通过后，后续阶段才有稳固地基。

相关文档：

- 总体规划：[docs/plan.md](../../docs/plan.md)
- 设计草案：[docs/design.md](../../docs/design.md)

## 范围（本期）

- HTTP/TLS 技术选型 spike，结论写入 design.md
- `hf_hub_download`：单文件下载全链路（revision 解析 → 下载 → 缓存落盘）
- HF 兼容缓存布局（blobs / snapshots / refs）
- 缓存命中与 etag 变更
- 断点续传（.incomplete + Range）
- 本地 mock 服务器测试基建
- CLI 的 `download` 命令

## 非范围（后续阶段）

- `snapshot_download`、认证、离线/镜像（阶段 2）
- API 端点、完整 CLI、错误语义全景（阶段 3）
- Python parity 套件、文档、演示（阶段 4）

## 验收

issues/ 下 4 个 issue 全部完成，且 `moon test`（native + wasm）通过。
