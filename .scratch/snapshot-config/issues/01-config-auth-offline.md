Status: ready-for-agent

## Parent

`.scratch/snapshot-config/PRD.md`

## What to build

扩展 `HubConfig` 与错误模型：

- `token` / `offline` 字段与 `with_token` / `with_offline` builder；
- `default_config()`：端点取 `HF_ENDPOINT`，token 依次取 `HF_TOKEN`、
  `HUGGING_FACE_HUB_TOKEN`、`~/.cache/huggingface/token`，离线取 `HF_HUB_OFFLINE`；
- 请求携带 `Authorization: Bearer <token>`；401/403 映射为 `GatedRepo`；
- 离线模式下，revision 未本地解析或文件未缓存时抛 `Offline`，不发任何网络请求。

## Acceptance criteria

- [x] gated 端点无 token 返回 401 → `GatedRepo`；带 token → 200
- [x] mock 记录到 `Authorization` 请求头
- [x] 离线 + 冷缓存 → `Offline`；离线 + 热缓存 → 正常返回

## Blocked by

None - can start immediately

## Comments

- 2026-09-14 完成。实现：`HubConfig.token/offline` + builder、`default_config`、
  `load_default_token`（env → token 文件）、`default_offline`、`auth_headers`；
  401/403 → `GatedRepo`；离线未缓存 → `Offline`（不发网络请求）。
  测试：`gated repo requires token`、`offline mode`。
