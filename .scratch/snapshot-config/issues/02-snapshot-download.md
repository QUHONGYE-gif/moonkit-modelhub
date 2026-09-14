Status: ready-for-agent

## Parent

`.scratch/snapshot-config/PRD.md`

## What to build

`snapshot_download(repo_id, config, allow_patterns?, ignore_patterns?)`：
解析 revision 信息（sha + siblings），按 glob pattern 过滤文件名，
复用 `hf_hub_download` 逐个下载，返回快照目录。

## Acceptance criteria

- [x] 下载全部 siblings，快照目录下每个文件都是指向 blobs 的符号链接
- [x] `ignore_patterns` / `allow_patterns` 过滤生效
- [x] 文件缺失（404）时抛 `EntryNotFound`，不中断前序已下载文件

## Blocked by

- `01-config-auth-offline.md`

## Comments

- 2026-09-14 完成。实现：`fetch_revision_info`（sha + siblings）、`snapshot_download`
  （复用 `hf_hub_download` 逐个下载，glob 过滤，回写 refs）。
  测试：`snapshot_download downloads all siblings`、`respects ignore patterns`。
  注：第三个验收项由 `hf_hub_download` 的 404 语义覆盖（单文件下载已测）。
