Status: ready-for-agent

## Parent

`.scratch/core-download/PRD.md`

## What to build

断点续传：下载写入 `.incomplete` 临时文件，利用 Range 头从中断处继续；中断或损坏
后再次调用能够恢复出完整文件。

## Acceptance criteria

- [ ] mock 注入中断后，再次调用从断点续传完成
- [ ] 最终文件哈希与全量下载一致；`.incomplete` 文件被清理

## Blocked by

- `02-single-file-download.md`
