Status: ready-for-agent

## Parent

`.scratch/core-download/PRD.md`

## What to build

实现 `hf_hub_download` 的最小闭环：解析 revision（mock `/api/models/<repo>/revision/<rev>`）
→ 经 `/resolve` 下载文件 → 按 etag 存入 `blobs/<etag>` → 在 `snapshots/<commit>/<file>`
建相对符号链接 → 写 `refs/<revision>` → 返回本地路径。CLI 增加
`download <repo> <file>` 命令；404 映射为 `EntryNotFound`。

## Acceptance criteria

- [ ] 对 mock 服务器执行 `download gpt2 config.json`，返回路径正确且文件内容一致
- [ ] 生成的缓存树与 huggingface_hub 布局一致（blobs / snapshots / refs 三层）
- [ ] 文件不存在时抛出 `EntryNotFound`
- [ ] 单测覆盖 revision 解析与缓存路径构造

## Blocked by

- `01-http-tls-spike.md`
