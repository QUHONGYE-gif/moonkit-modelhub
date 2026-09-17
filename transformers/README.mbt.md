# moonkit/transformers

GPT-2 级模型推理：safetensors 权重解析、完整前向、KV cache 贪心/温度生成。
配合 `QUHONGYE-gif/modelhub` 拉模型与 `tokenizers-moonbit` 分词，就是一条完整的
「拉模型 → 分词 → 生成 → 解码」流水线。

## 能力

- `parse_safetensors`：F32 权重解析（header JSON + data buffer）
- `parse_config` / `Gpt2Model::load`：config 解析与权重映射，
  自动识别 Conv1D（`[in,out]`）与 Linear（`[out,in]`）两种布局，
  bias 可选，`lm_head` 缺失时与 `wte` 绑定
- `Gpt2Model::forward`：wte+wpe → N×(LN→attn→残差→LN→MLP→残差) → ln_f → lm_head
- `Generator`：KV cache 增量前向 + 贪心/温度采样（增量结果与全量前向一致）

## 用法

```moonbit nocheck
///|
let cfg = @transformers.parse_config(config_json)

///|
let weights = @transformers.parse_safetensors(safetensors_bytes)

///|
let model = @transformers.Gpt2Model::load(cfg, weights)

///|
let logits = model.forward([1, 2, 3, 4])

///|
let ids = @transformers.Generator::new(model).generate([1, 2], 20, 0.0)
```

## 端到端演示

```bash
conda run -n moonbit bash scripts/demo_gpt2.sh   # 真实 tiny-random-gpt2，需网络
```

## 验证

```bash
conda run -n moonbit moon test --target native transformers/transformers_test.mbt
conda run -n moonbit python scripts/gen_gpt2_fixture.py   # 重新生成 golden fixture
```

numpy 参考实现覆盖前向 logits、贪心序列与增量一致性。
