Status: ready-for-agent

## Parent

`.scratch/onnx/PRD.md`

## What to build

`onnx/` 子包 + protobuf wire 解析（varint、fixed32/64、length-delimited、
packed repeated）与 ModelProto/GraphProto/NodeProto/TensorProto 子集。
fixture 由 Python onnx 包生成，测试对照 manifest 验证节点/初始器/属性。

## Acceptance criteria

- [x] 节点（op_type/inputs/outputs/attrs）与 manifest 一致
- [x] 初始器（名称/形状/F32 数值）与 manifest 一致
- [x] 截断输入抛明确错误

## Blocked by

None - can start immediately

## Comments

- 2026-09-17 完成。protobuf wire 解析（varint/fixed32-64/length-delimited/
  packed/unpacked repeated）+ ModelProto/GraphProto/NodeProto/TensorProto 子集，
  与 Python onnx 包生成的 manifest 对照一致。
