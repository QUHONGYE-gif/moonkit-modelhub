Status: ready-for-agent

## Parent

`.scratch/transformers/PRD.md`

## What to build

`transformers/` 子包 + safetensors 解析：8 字节 LE 头长度 → JSON header
（dtype/shape/data_offsets）→ 按名提取为 `nn.Tensor`（仅 F32）。

## Acceptance criteria

- [x] fixture 中全部张量形状/数值与 Python safetensors 读取一致
- [x] 未知 dtype 明确报错

## Blocked by

None - can start immediately

## Comments

- 2026-09-15 完成。`parse_safetensors`（F32 LE，header JSON + data buffer），
  与 Python safetensors 读取的 probe 一致；非 F32 dtype 抛错。
