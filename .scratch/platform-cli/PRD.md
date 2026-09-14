# PRD: 阶段 3 · 平台集成与 CLI

## 背景

阶段 1、2 已交付下载与接入配置。阶段 3 补齐元信息端点与完整 CLI，
让 modelhub 具备日常可用的命令行入口。

对应 GitHub issue #3。相关文档：[docs/plan.md](../../docs/plan.md)。

## 范围（本期）

- `model_info` / `dataset_info`：解析 id、sha、private、downloads、likes、siblings
- CLI 子命令：`modelhub download | snapshot | info`，参数经 `default_config()`
  继承环境变量（HF_ENDPOINT / HF_TOKEN / HF_HUB_CACHE）
- 错误语义收尾：所有对外 API 统一 `HubError` 变体，CLI 打印友好错误

## 非范围

- 上传、数据集查看器、Inference API

## 验收

issues/ 下 2 个 issue 全部完成，`moon test --target native` 全绿，
CLI 三个子命令对本地 mock 手动演示通过。
