# PRD: 阶段 8 · 生态收口与发布

## 背景

功能与验证已全部就绪（阶段 1–7）。阶段 8 做生态收口：可运行示例、
benchmark、文档总览，以及 mooncakes 发布准备。

对应 GitHub issue #9。相关文档：[docs/SUBMISSION.md](../../docs/SUBMISSION.md)。

## 范围（本期）

- `examples/`：tensor、onnx、hub 三个可运行示例 + 一键脚本
- `bench/`：张量算子与 GPT-2 前向的基准，结果写入 docs/BENCHMARK.md
- 文档总览：根 README 改为生态栈总览，各子包 README，docs/ARCHITECTURE.md
- 发布准备：moon.mod 元数据核对、`moon package/publish` 预检

## 非范围

- 真正的 mooncakes 上传（需要账号登录，由参赛者执行）

## 验收

examples 一键跑通；benchmark 有可复现数字；README 能让人 5 分钟理解整个栈。
