# moonkit：MoonBit × HuggingFace 生态栈

用纯 MoonBit 补齐 HuggingFace 生态的关键基础件，让 MoonBit 程序可以完整地
「拉模型 → 分词 → 跑推理」。仓库包含四个子包，每一层都有与 Python 生态
对照的自动化验证。

| 子包 | 定位 | 状态 | 验证方式 |
|---|---|---|---|
| `QUHONGYE-gif/modelhub` | HuggingFace Hub 客户端（下载/缓存/认证/离线/镜像） | ✅ | 与 huggingface_hub 1.31 缓存树逐文件 parity（本地 mock + 真实 hf-mirror，含 LFS） |
| `moonkit/nn` | 张量与推理内核（GEMM/激活/归一化/注意力/KV cache） | ✅ | numpy golden 逐元素对照 |
| `moonkit/transformers` | GPT-2 级模型推理（safetensors/前向/生成） | ✅ | numpy golden + 真实 tiny-random-gpt2 端到端生成 |
| `moonkit/onnx` | 通用 ONNX 图解释执行器（11 算子） | ✅ | numpy golden + 官方 ONNX backend test 子集 |

## 快速开始

开发环境隔离在 conda 环境 `moonbit` 中（工具链 + Python 测试依赖）：

```bash
conda activate moonbit
moon test --target native      # 全部测试（31 个）
moon test                      # wasm 目标（21 个）
```

一键体验：

```bash
bash scripts/run_examples.sh   # 张量 / ONNX / Hub 三个示例（Hub 用本地 mock）
bash scripts/demo_gpt2.sh      # 端到端：拉模型 → 分词 → 生成 → 解码（需网络）
bash scripts/bench.sh          # 基准（matmul / attention / GPT-2 / ONNX）
python scripts/parity_test.py  # 与 Python huggingface_hub 的 parity 验证
```

## 各子包用法

```moonbit nocheck
// 1) 拉模型（HF 兼容缓存）
///|
let config = @modelhub.HubConfig::new("https://hf-mirror.com", "/tmp/hf-cache")

///|
let path = @modelhub.hf_hub_download(
  "openai-community/gpt2", "config.json", config,
)

///|
let snapshot = @modelhub.snapshot_download(
  "sshleifer/tiny-gpt2",
  config,
  None,
  None,
)

// 2) 张量与算子

///|
let y = @nn.Tensor::randn([64, 64], 42UL).matmul(
  @nn.Tensor::randn([64, 64], 7UL),
)

///|
let probs = y.softmax()

// 3) GPT-2 推理（safetensors 权重 + KV cache 生成）

///|
let model = @transformers.Gpt2Model::load(
  cfg,
  @transformers.parse_safetensors(bytes),
)

///|
let text_ids = @transformers.Generator::new(model).generate(prompt_ids, 20, 0.0)

// 4) ONNX 图执行

///|
let graph = @onnx.parse_model(onnx_bytes)

///|
let outputs = @onnx.run_model(graph, inputs)
```

详见各子包文档：[nn](nn/README.mbt.md)、
[transformers](transformers/README.mbt.md)、[onnx](onnx/README.mbt.md)、
[modelhub 设计](docs/design.md)。

## 验证哲学

这个项目把「可验证」当作第一原则，三层验证都可用脚本复现：

1. **parity**：modelhub 在同一个服务端下与 Python `huggingface_hub` 生成的
   缓存树逐文件一致（`scripts/parity_test.py`，支持本地 mock 与真实端点）；
2. **golden**：nn / transformers / onnx 的全部算子与语义以 numpy 参考实现
   生成期望值、逐元素对照（`scripts/gen_*_fixture.py`）；
3. **官方一致性**：ONNX 侧直接跑官方 backend test 用例
   （`tests/fixtures/onnx-backend/`）。

## 文档索引

- [docs/plan.md](docs/plan.md) — 生态路线图与阶段划分
- [docs/design.md](docs/design.md) — modelhub 与推理内核设计决策
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — 分层、依赖与验证策略
- [docs/BENCHMARK.md](docs/BENCHMARK.md) — 基准数据与说明
- [docs/SUBMISSION.md](docs/SUBMISSION.md) — 参赛说明与验收对照
- [docs/APPLICATION.md](docs/APPLICATION.md) — 项目申报书

## 许可证

Apache-2.0
