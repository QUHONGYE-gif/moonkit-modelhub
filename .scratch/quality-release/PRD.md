# PRD: 阶段 4 · parity 质量与交付

## 背景

前三个阶段已交付全部核心功能。阶段 4 用「对照 Python huggingface_hub」的
parity 套件证明缓存布局与行为一致，并完成演示与验收整理。

对应 GitHub issue #4。相关文档：[docs/SUBMISSION.md](../../docs/SUBMISSION.md)。

## 范围（本期）

- parity 套件：同一 mock 服务器，Python huggingface_hub 与 modelhub 各跑一遍，
  两边缓存目录树 diff 为空
- 可复现演示脚本（demo + parity 一键运行）
- 文档收尾：README、SUBMISSION、验收清单

## 非范围

- 上传、LFS、性能对比

## 验收

`bash scripts/parity_test.sh`（或 python 版）输出 PARITY OK；
9/24 前完成验收清单全部勾选。
