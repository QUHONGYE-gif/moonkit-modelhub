///|
/// moonkit 基准：张量算子、注意力、GPT-2 前向、ONNX 图执行。
/// 运行（仓库根目录）：moon run bench --target native

///|
fn bench(name : String, count : Int, f : () -> Unit) -> Unit {
  let mut best = 1.0e18
  for _i in 0..<count {
    let t0 = @bench.monotonic_clock_start()
    f()
    let us = @bench.monotonic_clock_end(t0)
    if us < best {
      best = us
    }
  }
  println("\{name}: \{best / 1000.0} ms (best of \{count})")
}

///|
async fn load_json(path : String) -> Json {
  @json.parse(@fs.read_file(path).text()) catch {
    _ => abort("missing fixture: \{path}")
  }
}

///|
async fn main {
  println("== moonkit benchmarks ==")

  let a128 = @nn.Tensor::randn([128, 128], 1UL)
  let b128 = @nn.Tensor::randn([128, 128], 2UL)
  bench("matmul 128x128", 3, fn() {
    let _ = a128.matmul(b128) catch { e => abort("\{e}") }
  })

  let a256 = @nn.Tensor::randn([256, 256], 3UL)
  let b256 = @nn.Tensor::randn([256, 256], 4UL)
  bench("matmul 256x256", 3, fn() {
    let _ = a256.matmul(b256) catch { e => abort("\{e}") }
  })

  let q = @nn.Tensor::randn([2, 64, 64], 5UL)
  let k = @nn.Tensor::randn([2, 64, 64], 6UL)
  let v = @nn.Tensor::randn([2, 64, 64], 7UL)
  bench("attention [2,64,64] causal", 3, fn() {
    let _ = @nn.attention(q, k, v, true) catch { e => abort("\{e}") }
  })

  // GPT-2 前向（fixture 小模型）
  let cfg = @transformers.parse_config(
    load_json("tests/fixtures/gpt2-model/config.json"),
  ) catch {
    e => abort("\{e}")
  }
  let weights = @transformers.parse_safetensors(
    @fs.read_file("tests/fixtures/gpt2-model/model.safetensors").binary(),
  ) catch {
    e => abort("\{e}")
  }
  let model = @transformers.Gpt2Model::load(cfg, weights) catch {
    e => abort("\{e}")
  }
  bench("gpt2 forward (2 layers, 8 tokens)", 3, fn() {
    let _ = model.forward([1, 2, 3, 4, 5, 6, 7, 8]) catch { e => abort("\{e}") }
  })

  // ONNX 图执行（fixture 模型，10 节点）
  let onnx_model = @onnx.parse_model(
    @fs.read_file("tests/fixtures/onnx/model.onnx").binary(),
  ) catch {
    e => abort("\{e}")
  }
  let inputs : Map[String, @nn.Tensor] = Map([])
  inputs["X"] = @nn.Tensor::randn([2, 4], 8UL)
  bench("onnx graph run (10 nodes)", 3, fn() {
    let _ = @onnx.run_model(onnx_model, inputs) catch { e => abort("\{e}") }
  })
}
