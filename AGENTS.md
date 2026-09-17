# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.

## 本项目开发环境

- MoonBit 工具链安装在 conda 环境 `moonbit` 内部（`$CONDA_PREFIX/moon`），
  **不在全局 PATH**。执行任何 `moon` 命令前先激活：
  `conda activate moonbit`，或在脚本里用 `conda run -n moonbit moon ...`。
- 工具链版本：moon 0.1.20260904。升级走官方安装脚本并保持 `MOON_HOME=$CONDA_PREFIX/moon`。
- Python parity 测试依赖（`huggingface_hub` 等）同样安装在该 conda 环境。

## 项目约定

- 库代码在顶层包 `QUHONGYE-gif/modelhub`；CLI 入口在 `cmd/main`。
- HTTP/TLS 技术选型必须先经 spike 并把结论写入 `docs/design.md`，
  结论落定前不要写大量依赖某一实现的代码。
- 与 `huggingface_hub` 的行为差异必须记录在案（文档或代码注释），
  因为 parity 是本项目的核心卖点。

## 仓库级 Agent Skills

本仓库在 `.agents/skills/` 下安装了 11 个工程类 skills（来自个人 ai-skills-library 的
engineering 分类）。任务匹配时按需使用，使用前先完整阅读对应 `SKILL.md`：

- `tdd` 测试驱动开发（红-绿-重构）；`triage` issue 分流与状态管理；
  `to-prd` 整理 PRD 并发布到 issue tracker；`to-issues` 把计划拆成垂直切片 issues
- `grill-with-docs` 结合 CONTEXT.md 与 ADR 拷问方案；`improve-codebase-architecture`
  架构/解耦/可测试性改进；`zoom-out` 在陌生代码区域上升抽象层
- `prototype` 一次性原型验证；`playwright` 浏览器自动化；
  `diagnose` 可复现反馈回路诊断 hard bug
- `setup-matt-pocock-skills` 配置 issue tracker、triage labels 与领域文档
  （已完成配置：本地 markdown issue + 默认 triage 标签 + single-context）

## Agent skills

### Issue tracker

Issues and PRDs live as local markdown files under `.scratch/<feature-slug>/`.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles map to themselves (`needs-triage`, `needs-info`,
`ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: `CONTEXT.md` at the repo root plus `docs/adr/`.
See `docs/agents/domain.md`.
