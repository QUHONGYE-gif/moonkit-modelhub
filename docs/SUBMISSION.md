# 参赛说明（2026 MoonBit 九月黑客松）

## 项目

**modelhub** —— MoonBit 的 HuggingFace Hub 客户端库（`moonkit/modelhub`）。
用纯 MoonBit 实现与 Python `huggingface_hub` 兼容的模型仓库下载、修订版本解析
与缓存管理，让 MoonBit 程序可以用 `hf_hub_download("gpt2", "config.json")`
直接接入 HuggingFace 生态。

核心卖点是 **parity**：本地缓存目录结构与行为对齐官方客户端
（`blobs/<etag>`、`snapshots/<commit>/`、`refs/<revision>`），两边生成的缓存可互认。

仓库：<https://github.com/QUHONGYE-gif/moonkit-modelhub>

## 验收标准对照

| 赛事要求 | 本项目 |
|---|---|
| MoonBit 为主要实现语言 | ✅ 纯 MoonBit，无 FFI；依赖官方 `moonbitlang/async` |
| 仓库公开、提交可追踪 | ✅ 公开仓库；commits / issues / PR 完整保留 |
| 能够运行（README + 示例 + 测试） | ✅ README、CLI 示例、`moon test` 6/6 通过 |
| 已有项目须有实质新增工作 | ✅ 本期从零实现 |
| 开源合规 | ✅ Apache-2.0，无移植代码 |
| AI 可解释 | ✅ 见文末「AI 协作说明」 |

## 当前进度（阶段 1–4 已完成，09-14）

- **HTTP/TLS 选型**：`moonbitlang/async@0.21.3`，native/wasm/js 三后端可用，
  结论与验证记录见 [design.md](design.md)。
- **单文件下载全链路**：`hf_hub_download`（revision 解析 → `/resolve` → 302
  跟随 → 按 ETag 落盘 → snapshot 符号链接 → refs 映射）。
- **缓存 parity**：缓存树与 `huggingface_hub` 布局一致；命中缓存零网络请求；
  etag 变更生成新 blob/snapshot。
- **断点续传**：`.incomplete` + `Range` 续传，中断恢复完整。
- **快照下载**：`snapshot_download` 解析 siblings 并按 glob pattern 批量下载。
- **接入配置**：`HF_TOKEN` / `HUGGING_FACE_HUB_TOKEN` / token 文件认证，
  `HF_HUB_OFFLINE` 离线模式，`HF_ENDPOINT` 镜像；401/403 → `GatedRepo`。
- **元信息与 CLI**：`model_info` / `dataset_info`；CLI 子命令
  `modelhub download | snapshot | info`（环境变量继承 + 命令行覆盖）。
- **parity 验证**：与 Python huggingface_hub 1.31 在同一 mock 上生成的缓存树
  逐文件一致（`scripts/parity_test.py` 输出 PARITY OK）。
- **真实端点验证**：对 `https://hf-mirror.com` 的 `sshleifer/tiny-gpt2`
  （9 个文件，含 pytorch_model.bin / tf_model.h5 / flax_model.msgpack 三个
  LFS 二进制）完整 snapshot，缓存树与 Python 端逐文件一致（PARITY OK）。

测试：native 目标 12/12 通过（进程内 mock 服务器），wasm 目标通过；
三个 CLI 子命令与一键 demo 对本地 mock 演示通过。

## 如何运行

```bash
conda activate moonbit          # 工具链隔离在该环境内
moon test --target native       # 全部测试

# CLI 演示（先起本地 mock）：
python3 scripts/mock_hub_server.py &
moon run cmd/main --target native -- gpt2 config.json \
  --endpoint http://127.0.0.1:8765 --cache-dir /tmp/modelhub-demo
find /tmp/modelhub-demo        # 观察 HF 兼容缓存树

# 一键演示与 parity 验证：
bash scripts/demo.sh
python scripts/parity_test.py

# 真实端点 parity（可选，需联网）：
PARITY_ENDPOINT=https://hf-mirror.com PARITY_REPO=sshleifer/tiny-gpt2 \
  python scripts/parity_test.py
```

## 路线图

- 阶段 1 · 技术验证与核心下载 ✅（issue #1）
- 阶段 2 · 快照下载与接入配置 ✅（issue #2）
- 阶段 3 · 平台集成与 CLI ✅（issue #3）
- 阶段 4 · parity 质量与交付 ✅（issue #4）
- 候选池 · transformers.mbt / onnx.mbt（复用 modelhub 作为地基）

## AI 协作说明

开发全程使用 Codex（AI 编程助手）辅助，方式如下：

- AI 负责：官方文档/生态调研、依赖 API 确认、脚手架、mock 服务器与测试用例、
  实现草稿与格式化；
- 人工负责并最终确认：技术选型（HTTP/TLS）、缓存布局的 parity 语义、错误模型、
  每处关键实现与全部测试结果；
- 关键决策落盘于 `docs/design.md` / `docs/plan.md`，开发过程以提交历史与
  GitHub issues 全程留痕。

AI 参与的目的是加速探索与起草，目标、路径与质量由参赛者掌握。
