///|
/// onnx.mbt 演示：解析 fixture 模型并执行，输出与 numpy 参考对比。
/// 运行（仓库根目录）：moon run examples/onnx_demo --target native
async fn main {
  let model_bytes = @fs.read_file("tests/fixtures/onnx/model.onnx").binary() catch {
    _ => abort("请从仓库根目录运行本示例")
  }
  let model = @onnx.parse_model(model_bytes) catch {
    e => abort("parse failed: \{e}")
  }
  println("opset: \{model.opset}")
  println("nodes: \{model.graph.nodes.length()}")
  println("initializers: \{model.graph.initializers.length()}")

  let fixture_text = @fs.read_file("tests/fixtures/onnx/expected_outputs.json").text() catch {
    _ => abort("missing fixture")
  }
  let fixture = @json.parse(fixture_text) catch {
    _ => abort("bad fixture json")
  }
  let input_json = match fixture {
    Json::Object(o) =>
      match o.get("input") {
        Some(v) => v
        None => abort("missing input")
      }
    _ => abort("bad fixture")
  }
  let shape = match input_json {
    Json::Object(o) =>
      match o.get("shape") {
        Some(Json::Array(items)) =>
          items.map(fn(x) {
            match x {
              Json::Number(d, ..) => d.to_int()
              _ => 0
            }
          })
        _ => abort("bad shape")
      }
    _ => abort("bad input")
  }
  let data = match input_json {
    Json::Object(o) =>
      match o.get("data") {
        Some(Json::Array(items)) =>
          items.map(fn(x) {
            match x {
              Json::Number(d, ..) => d
              _ => 0.0
            }
          })
        _ => abort("bad data")
      }
    _ => abort("bad input")
  }
  let x = @nn.Tensor::new(shape, data) catch {
    e => abort("bad input tensor: \{e}")
  }
  let inputs : Map[String, @nn.Tensor] = Map([])
  inputs["X"] = x
  let registry = @onnx.run_model(model, inputs) catch {
    e => abort("run failed: \{e}")
  }
  let out = match registry.get("O") {
    Some(t) => t
    None => abort("missing output O")
  }
  println("output shape: \{@debug.to_string(out.shape)}")
  println("output data:  \{@debug.to_string(out.data)}")
}
