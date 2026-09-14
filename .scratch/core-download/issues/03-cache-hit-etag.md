Status: ready-for-agent

## Parent

`.scratch/core-download/PRD.md`

## What to build

`hf_hub_download` 的缓存语义：同一 revision 重复调用不发任何网络请求；当 etag
变化时重新下载，生成新的 blob 与 snapshot，并更新 refs 指向。

## Acceptance criteria

- [ ] 第二次调用零 HTTP 请求（mock 记录为 0）
- [ ] etag 变化后产生新 blob 与新 snapshot，refs 更新
- [ ] 旧 blob 保留，不破坏其它 snapshot 的去重共享

## Blocked by

- `02-single-file-download.md`
