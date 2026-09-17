# moonkit/nn

纯 MoonBit 的 Double 张量与推理内核，是 `transformers` 与 `onnx` 两个子包
共用的地基。正确性优先：所有算子以 numpy 为参考实现生成 golden 数据逐元素对照。

## 算子清单

- 张量：`new` / `zeros` / `randn`（可复现种子）/ `reshape` / `transpose` / `permute`
- 逐元素：`add` / `sub` / `mul` / `scale` / `add_bias`（末维广播）
- 矩阵：`matmul`（2D、3D batch、3D×2D）
- 激活与归一化：`relu` / `sigmoid` / `tanh` / `gelu`（tanh 近似）/
  `softmax` / `softmax_axis`（任意维）/ `layer_norm` / `rms_norm`
- 注意力：`attention`（causal mask）/ `concat_2d` / `cat_seq`（KV cache）

## 用法

```moonbit nocheck
///|
let a = @nn.Tensor::randn([128, 128], 42UL)

///|
let b = @nn.Tensor::randn([128, 128], 7UL)

///|
let c = a.matmul(b).gelu()

///|
let p = c.softmax()
```

## 验证

```bash
conda run -n moonbit moon test --target native nn/nn_test.mbt
conda run -n moonbit python scripts/gen_nn_golden.py   # 重新生成 golden fixture
```

约定：MVP 使用 Double(f64) 与朴素实现（无分块/SIMD），性能优化见
[docs/BENCHMARK.md](../docs/BENCHMARK.md)。
