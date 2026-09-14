Status: ready-for-agent

## Parent

`.scratch/core-download/PRD.md`

## What to build

断点续传：下载写入 `.incomplete` 临时文件，利用 Range 头从中断处继续；中断或损坏
后再次调用能够恢复出完整文件。

## Acceptance criteria

- [x] mock 注入中断后，再次调用从断点续传完成
- [x] 最终文件哈希与全量下载一致；`.incomplete` 文件被清理

## Blocked by

- `02-single-file-download.md`

## Comments

- 2026-09-14 完成。实现：`copy_stream` 流式写入 `blobs/<etag>.incomplete`，
  中断保留已写部分；重试时携带 `Range: bytes=<offset>-` 续传（206），
  完成后 `rename` 为最终 blob 并清理 `.incomplete`。
  测试：`resume download after interruption`（服务端注入 5 字节后断连）。
