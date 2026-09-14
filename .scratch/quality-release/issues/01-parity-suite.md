Status: ready-for-agent

## Parent

`.scratch/quality-release/PRD.md`

## What to build

`scripts/parity_test.py`：启动本地 mock，分别用 Python huggingface_hub
（`HF_ENDPOINT` 指向 mock）与 modelhub CLI 下载同一仓库，比较两边缓存目录树
（含符号链接目标），输出 PARITY OK / FAILED。

## Acceptance criteria

- [x] 同一 mock 上两边缓存树 diff 为空
- [x] 脚本可一键运行（含 mock 启停与清理）

## Blocked by

None - can start immediately

## Comments

- 2026-09-14 完成。`scripts/parity_test.py` 输出 PARITY OK：
  modelhub 与 huggingface_hub 1.31 在同一 mock 上生成的缓存树逐文件一致
  （含 CACHEDIR.TAG、.locks、refs、snapshots 符号链接、trees/<sha>.json）。
  为此对齐了 trees 缓存格式、refs 写入规则、.locks 与 CACHEDIR.TAG。
- 2026-09-14 真实端点验证：`PARITY_ENDPOINT=https://hf-mirror.com
  PARITY_REPO=sshleifer/tiny-gpt2`（9 个文件含 LFS 二进制）同样 PARITY OK。
  过程中修复：弱 ETag（W/）处理、重定向链上 X-Linked-Etag（LFS oid）捕获、
  CLI 错误退出码。
