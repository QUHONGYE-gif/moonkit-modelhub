Status: ready-for-agent

## Parent

`.scratch/release/PRD.md`

## What to build

`examples/` 三个可运行示例 + `scripts/run_examples.sh`：
tensor（张量/算子）、onnx（跑 fixture 模型）、hub（对本地 mock 下载）。

## Acceptance criteria

- [x] 三个示例均可 `moon run` 直接跑通
- [x] 一键脚本串联全部示例

## Blocked by

None - can start immediately

## Comments

- 2026-09-17 完成。examples/{tensor_demo,onnx_demo,hub_demo} +
  scripts/run_examples.sh；顺带修复 mock 的 /cdn 按文件名误匹配问题
  （两个 repo 都有 config.json 时取错内容），parity 复验通过。
