# moonkit/onnx

通用 ONNX 图解释执行器：解析 ONNX（protobuf）模型并在 MoonBit 中执行，
让 PyTorch 等框架导出的模型可以直接在 MoonBit 里跑推理。

## 能力

- protobuf wire 解析（varint / fixed32-64 / length-delimited，兼容 packed 与
  非 packed repeated），覆盖 ModelProto / GraphProto / NodeProto / TensorProto
- 图执行器：张量注册表 + 按依赖调度，支持任意有向无环拓扑
- 算子集 v1：`Gemm`（alpha/beta/transA/transB + C 广播）、`MatMul`、`Add`、
  `Relu`、`Sigmoid`、`Tanh`、`Softmax`（任意 axis）、`Reshape`、`Flatten`、
  `Transpose`（perm）、`Concat`

## 用法

```moonbit nocheck
let model = @onnx.parse_model(onnx_bytes)
let inputs : Map[String, @nn.Tensor] = Map([])
inputs["X"] = @nn.Tensor::new([2, 4], data)
let outputs = @onnx.run_model(model, inputs)
```

## 验证

```bash
conda run -n moonbit moon test --target native onnx/onnx_test.mbt
```

两层验证：numpy 参考逐中间量 golden，以及官方 ONNX backend test 子集
（`tests/fixtures/onnx-backend/`：gemm_all_attributes、relu、softmax_axis_1、
matmul_2d、add）。
