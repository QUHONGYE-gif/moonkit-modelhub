Status: ready-for-agent

## Parent

`.scratch/platform-cli/PRD.md`

## What to build

`model_info` / `dataset_info`：GET `/api/{models|datasets}/<repo>`，
解析为 `RepoInfo { id, sha, private, downloads, likes, siblings }`；
401/403 → `GatedRepo`，404 → `RevisionNotFound`。

## Acceptance criteria

- [x] happy path 解析全部字段（含 siblings）
- [x] 404 → `RevisionNotFound`；401 → `GatedRepo`

## Blocked by

None - can start immediately

## Comments

- 2026-09-14 完成。实现：`info.mbt` 的 `RepoInfo` / `model_info` / `dataset_info`，
  复用 `parse_siblings`；测试：`model_info parses metadata and maps 404`。
