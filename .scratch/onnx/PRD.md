# PRD: 阶段 7 · onnx.mbt（通用 ONNX 图执行器）

## 背景

生态栈的最后一环：用 MoonBit 执行 ONNX 图，让 PyTorch/其他框架导出的模型
可以在 MoonBit 中推理。差异化于 mbtorch 的「模式匹配导入器」——我们做
**任意拓扑的图解释执行器**。

对应 GitHub issue #8。相关文档：[docs/plan.md](../../docs/plan.md)。

## 范围（本期）

- protobuf wire 解析器（varint/fixed/length-delimited）与 ONNX ModelProto /
  GraphProto / NodeProto / TensorProto 子集解析
- 图执行器：拓扑排序、张量注册表、按 op_type 分发
- 算子集 v1：Gemm / MatMul / Add / Relu / Sigmoid / Tanh / Softmax /
  Reshape / Flatten / Transpose / Concat（复用 moonkit/nn）
- 验收：官方 ONNX backend test 的 Gemm/Relu/Softmax/MatMul/Add 子集

## 非范围

- Conv/Pool 等 CNN 算子（后续）、量化、LSTM、控制流算子

## 验收

issues/ 下 4 个 issue 全部完成；`moon test --target native` 全绿；
官方 backend test 子集跑通。
