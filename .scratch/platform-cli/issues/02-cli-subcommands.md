Status: ready-for-agent

## Parent

`.scratch/platform-cli/PRD.md`

## What to build

CLI 重构为子命令结构：`modelhub download <repo> <file>`、
`modelhub snapshot <repo> [--include GLOB] [--exclude GLOB]`、
`modelhub info <repo>`。全局参数（endpoint/cache-dir/revision）经
`default_config()` 从环境变量继承，可被命令行覆盖。错误输出到 stderr 风格的单行提示。

## Acceptance criteria

- [x] 三个子命令对本地 mock 演示通过
- [x] `--include` / `--exclude` 可重复出现并生效
- [x] 未提供子命令时打印帮助

## Blocked by

- `01-repo-info.md`

## Comments

- 2026-09-14 完成。CLI 重构为子命令（download/snapshot/info），
  全局配置经 `default_config()` 继承环境变量、可被命令行覆盖。
  对本地 mock 演示：info 输出元信息、snapshot --exclude 过滤、
  download 单文件、无子命令打印 usage。
