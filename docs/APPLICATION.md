# moonkit 项目申报书

## 基本信息

- 项目名称：moonkit：MoonBit 的 HuggingFace 生态栈（modelhub / nn / transformers）
- 参赛者：＿＿＿＿＿＿（请填写姓名）
- 联系方式：＿＿＿＿＿＿（请填写手机号/微信号）
- GitHub 仓库链接：https://github.com/QUHONGYE-gif/moonkit-modelhub
- 项目方向：Web 与网络基础设施（HuggingFace Hub 客户端 / 服务端基础组件）＋ 应用与内容工具（LLM 推理工具链）
- 是否为移植项目：否（原创实现；行为 parity 与 golden 测试以 Python 生态为参照，见下文「参照与合规说明」）

## 项目简介

moonkit 用纯 MoonBit 补齐 HuggingFace 生态在 MoonBit 世界的关键基础件，让 MoonBit 程序
能够完整地「拉模型 → 跑推理 → 生成文本」。项目由三部分组成：

- **modelhub**：与 Python huggingface_hub 缓存布局与下载行为完全一致（parity）的
  HuggingFace Hub 客户端。支持单文件/快照下载、认证、离线模式、镜像端点与断点续传，
  已通过本地 mock 与真实 hf-mirror（含 LFS 二进制）的双重逐文件对比验证。
- **moonkit/nn**：自研的 Double 张量与推理内核（GEMM、激活、归一化、注意力、KV cache），
  全部算子以 numpy 为参考实现生成 golden 数据逐元素对照。
- **transformers.mbt**：GPT-2 级模型推理（safetensors 权重加载、前向、KV cache 贪心/温度
  采样生成），复用 tokenizers-moonbit 与 modelhub，已对真实
  `hf-internal-testing/tiny-random-gpt2` 跑通端到端生成。

整个项目强调「可验证」：每一层都配有与 Python 生态对照的 parity / golden 测试，
一键脚本可复现全部验证结果。

## 核心功能范围

- HuggingFace Hub 客户端：`hf_hub_download` / `snapshot_download` / `model_info` /
  `dataset_info`，支持 revision 解析、glob 过滤、ETag/LFS 语义；
- 与 huggingface_hub 完全一致的缓存布局：`blobs/<etag>`、`snapshots/<commit>/`、
  `refs/`、`trees/<sha>.json`、`.locks/`、`CACHEDIR.TAG`；
- 认证（`HF_TOKEN` / `HUGGING_FACE_HUB_TOKEN` / token 文件）、离线模式
  （`HF_HUB_OFFLINE`）、镜像端点（`HF_ENDPOINT`，如 hf-mirror.com）；
- 断点续传（`.incomplete` + `Range`）；错误语义对齐（`GatedRepo`、`EntryNotFound`、
  `RevisionNotFound`、`Offline`）；
- CLI：`modelhub download | snapshot | info`；
- 推理内核 `moonkit/nn`：张量（reshape/transpose/randn/逐元素）、GEMM（2D/3D/batch）、
  GELU/Softmax/LayerNorm/RMSNorm、scaled dot-product attention（causal/多头）；
- transformers.mbt：safetensors（F32）解析、GPT-2 配置与权重加载（兼容 Conv1D 与
  Linear 两种权重布局、可选 bias、tied lm_head）、完整前向、KV cache 增量生成；
- 端到端演示：`scripts/demo_gpt2.sh` 一键完成「拉模型 → 分词 → 生成 → 解码」；
- 测试：native 28/28、wasm 18/18；parity 与 golden 均由脚本一键复现
  （`scripts/parity_test.py`、`scripts/gen_nn_golden.py`、`scripts/gen_gpt2_fixture.py`）。

## 参照与合规说明

- 本项目为原创 MoonBit 实现，不复制任何第三方代码。
- 行为 parity 参照：Python `huggingface_hub`（Apache-2.0）——以同一服务端下的
  缓存树逐文件对比为验收标准；
- golden 测试参照：`numpy`（BSD）与 HuggingFace `transformers`（Apache-2.0）的
  GPT-2 语义——仅用于生成期望值，不纳入其实现代码；
- 使用的 MoonBit 生态依赖：`moonbitlang/async`（Apache-2.0）、
  `howtomakeaname/tokenizers-moonbit`（Apache-2.0）；
- 本项目许可证：Apache-2.0。

## AI 协作说明

开发全程使用 Codex（AI 编程助手）辅助：AI 负责官方文档与生态调研、依赖 API 确认、
脚手架、mock 服务器与测试用例、实现草稿与格式化；技术选型（HTTP/TLS 传输层、
缓存 parity 语义、权重布局兼容、错误模型）由参赛者评审并最终确认，关键决策落盘于
`docs/design.md` / `docs/plan.md`，开发过程以提交历史与 GitHub issues 全程留痕。
