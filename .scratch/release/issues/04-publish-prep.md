Status: ready-for-agent

## Parent

`.scratch/release/PRD.md`

## What to build

发布准备：核对 moon.mod 元数据（描述/关键词/许可证/仓库），跑
`moon package`（或 publish 预检）确认可以打包；把发布步骤写入文档，
真正的 `moon publish` 交给参赛者（需要 mooncakes 账号）。

## Acceptance criteria

- [x] 打包预检通过
- [x] 发布步骤写入 docs/RELEASE.md

## Blocked by

- `03-docs.md`

## Comments

- 2026-09-17 完成。`moon package` 通过（Check passed，产出
  _build/publish/moonkit-modelhub-0.1.0.zip）；`moon publish --dry-run`
  需要先 `moon login`（账号步骤由参赛者执行），步骤写入 docs/RELEASE.md。
