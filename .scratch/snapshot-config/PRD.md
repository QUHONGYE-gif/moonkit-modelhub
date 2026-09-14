# PRD: 阶段 2 · 快照下载与接入配置

## 背景

modelhub 阶段 1 已交付单文件下载与 HF 兼容缓存。阶段 2 补齐「按快照批量下载」
与「接入配置」：认证、离线模式、镜像端点，使库能对接真实 HuggingFace 与 hf-mirror。

对应 GitHub issue #2。相关文档：[docs/plan.md](../../docs/plan.md)、
[docs/design.md](../../docs/design.md)。

## 范围（本期）

- `snapshot_download`：解析 revision + siblings 列表，按 pattern 过滤后批量下载
- 认证：`HF_TOKEN` / `HUGGING_FACE_HUB_TOKEN` 环境变量与 token 文件
- 离线：`HF_HUB_OFFLINE`；离线且未命中缓存时抛 `Offline`
- 镜像：`HF_ENDPOINT`（已有，本期补文档与测试）
- gated repo：401/403 → `GatedRepo`

## 非范围

- 上传、LFS、数据集查看器
- CLI `snapshot` 子命令（阶段 3 与 argparse 子命令 API 一起做）

## 验收

issues/ 下 2 个 issue 全部完成，`moon test --target native` 全绿。
