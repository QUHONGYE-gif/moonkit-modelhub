// onnx 黑盒测试：fixture 来自 scripts/gen_onnx_fixture.py。

///|
fn json_field(j : Json, key : String) -> Json? {
  match j {
    Json::Object(o) => o.get(key)
    _ => None
  }
}

///|
fn json_string(j : Json?) -> String {
  match j {
    Some(Json::String(s)) => s
    _ => ""
  }
}

///|
fn json_strings(j : Json?) -> Array[String] {
  match j {
    Some(Json::Array(items)) => {
      let out : Array[String] = []
      for item in items {
        let _ = out.push(json_string(Some(item)))
      }
      out
    }
    _ => []
  }
}

///|
fn json_doubles(j : Json?) -> Array[Double] {
  match j {
    Some(Json::Array(items)) => {
      let out : Array[Double] = []
      for item in items {
        match item {
          Json::Number(d, ..) => {
            let _ = out.push(d)
          }
          _ => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
fn json_ints(j : Json?) -> Array[Int] {
  match j {
    Some(Json::Array(items)) => {
      let out : Array[Int] = []
      for item in items {
        match item {
          Json::Number(d, ..) => {
            let _ = out.push(d.to_int())
          }
          _ => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
fn json_int(j : Json?) -> Int {
  match j {
    Some(Json::Number(d, ..)) => d.to_int()
    _ => 0
  }
}

///|
fn json_double(j : Json?) -> Double {
  match j {
    Some(Json::Number(d, ..)) => d
    _ => 0.0
  }
}

///|
async fn load_bytes(name : String) -> Bytes {
  for
    candidate in [
      "tests/fixtures/onnx/\{name}",
      "../../tests/fixtures/onnx/\{name}",
    ] {
    let bytes = @fs.read_file(candidate).binary() catch { _ => continue }
    return bytes
  }
  abort("missing fixture: \{name}")
}

///|
async fn load_backend_bytes(name : String) -> Bytes {
  for
    candidate in [
      "tests/fixtures/onnx-backend/\{name}",
      "../../tests/fixtures/onnx-backend/\{name}",
    ] {
    let bytes = @fs.read_file(candidate).binary() catch { _ => continue }
    return bytes
  }
  abort("missing backend fixture: \{name}")
}

///|
async fn load_json(name : String) -> Json {
  for
    candidate in [
      "tests/fixtures/onnx/\{name}",
      "../../tests/fixtures/onnx/\{name}",
    ] {
    let text = @fs.read_file(candidate).text() catch { _ => continue }
    return @json.parse(text) catch {
      _ => abort("invalid fixture: \{candidate}")
    }
  }
  abort("missing fixture: \{name}")
}

///|
async test "parse onnx model matches manifest" {
  let model = @onnx.parse_model(load_bytes("model.onnx")) catch {
    e => abort("parse failed: \{e}")
  }
  let manifest = load_json("manifest.json")
  assert_eq(
    model.ir_version.to_int(),
    json_int(json_field(manifest, "ir_version")),
  )
  assert_eq(model.opset.to_int(), json_int(json_field(manifest, "opset")))

  let nodes_json = match json_field(manifest, "nodes") {
    Some(Json::Array(items)) => items
    _ => abort("bad manifest nodes")
  }
  assert_eq(model.graph.nodes.length(), nodes_json.length())
  for i in 0..<nodes_json.length() {
    let nj = nodes_json[i]
    let node = model.graph.nodes[i]
    assert_eq(node.op_type, json_string(json_field(nj, "op_type")))
    assert_eq(node.inputs, json_strings(json_field(nj, "inputs")))
    assert_eq(node.outputs, json_strings(json_field(nj, "outputs")))
    let attrs_json = match json_field(nj, "attrs") {
      Some(Json::Object(o)) => o
      _ => Map([])
    }
    for (key, value) in attrs_json {
      let kind = json_string(json_field(value, "kind"))
      match node.attrs.get(key) {
        Some(@onnx.AttrValue::Float(f)) if kind == "float" =>
          assert_true(
            (f - json_double(json_field(value, "value"))).abs() < 1.0e-6,
          )
        Some(@onnx.AttrValue::Int(iv)) if kind == "int" =>
          assert_eq(iv.to_int(), json_int(json_field(value, "value")))
        Some(@onnx.AttrValue::Str(s)) if kind == "str" =>
          assert_eq(s, json_string(json_field(value, "value")))
        _ if kind == "ndarray" || kind == "list" => ()
        _ => abort("attr mismatch: \{key} = \{kind}")
      }
    }
  }

  let inits_json = match json_field(manifest, "initializers") {
    Some(Json::Array(items)) => items
    _ => abort("bad manifest initializers")
  }
  for item in inits_json {
    let name = json_string(json_field(item, "name"))
    let t = match model.graph.initializers.get(name) {
      Some(t) => t
      None => abort("missing initializer \{name}")
    }
    assert_eq(t.shape, json_ints(json_field(item, "shape")))
    let expected = json_doubles(json_field(item, "data"))
    assert_true(t.data.length() >= expected.length(), msg="short tensor data")
    for k in 0..<expected.length() {
      assert_true((t.data[k] - expected[k]).abs() < 1.0e-6)
    }
  }
}

///|
async test "run onnx model matches numpy reference" {
  let model = @onnx.parse_model(load_bytes("model.onnx")) catch {
    e => abort("parse failed: \{e}")
  }
  let expected_json = load_json("expected_outputs.json")
  let input_json = match json_field(expected_json, "input") {
    Some(v) => v
    None => abort("missing input in fixture")
  }
  let x = @nn.Tensor::new(
    json_ints(json_field(input_json, "shape")),
    json_doubles(json_field(input_json, "data")),
  ) catch {
    e => abort("bad input: \{e}")
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
  let intermediates = match json_field(expected_json, "intermediates") {
    Some(Json::Object(o)) => o
    _ => abort("missing intermediates")
  }
  for (name, meta) in intermediates {
    let t = match registry.get(name) {
      Some(t) => t
      None => abort("missing intermediate \{name}")
    }
    assert_eq(
      t.shape,
      json_ints(json_field(meta, "shape")),
      msg="shape of \{name}",
    )
    let exp = json_doubles(json_field(meta, "data"))
    for i in 0..<exp.length() {
      let d = t.data[i] - exp[i]
      assert_true(
        d < 1.0e-4 && d > -1.0e-4,
        msg="\{name}[ \{i}]: \{t.data[i]} vs \{exp[i]}",
      )
    }
  }
  assert_eq(out.shape, json_ints(json_field(expected_json, "shape")))
  let expected = json_doubles(json_field(expected_json, "expected"))
  assert_eq(out.data.length(), expected.length())
  for i in 0..<expected.length() {
    let d = out.data[i] - expected[i]
    assert_true(
      d < 1.0e-4 && d > -1.0e-4,
      msg="mismatch at \{i}: \{out.data[i]} vs \{expected[i]}",
    )
  }
}

///|
async test "official onnx backend test subset" {
  // (case 名, 输入个数)
  let cases = [
    ("test_gemm_all_attributes", 3),
    ("test_relu", 1),
    ("test_softmax_axis_1", 1),
    ("test_matmul_2d", 2),
    ("test_add", 2),
  ]
  for (case_name, input_count) in cases {
    let model = @onnx.parse_model(load_backend_bytes("\{case_name}/model.onnx")) catch {
      e => abort("\{case_name}: parse failed: \{e}")
    }
    let inputs : Map[String, @nn.Tensor] = Map([])
    for i in 0..<input_count {
      let name = if i < model.graph.inputs.length() {
        model.graph.inputs[i]
      } else {
        ""
      }
      let t = @onnx.parse_tensor_bytes(
        load_backend_bytes("\{case_name}/test_data_set_0/input_\{i}.pb"),
      ) catch {
        e => abort("\{case_name}: input parse failed: \{e}")
      }
      let tensor = @nn.Tensor::new(t.shape, t.data) catch {
        e => abort("\{case_name}: bad input: \{e}")
      }
      inputs[name] = tensor
    }
    let registry = @onnx.run_model(model, inputs) catch {
      e => abort("\{case_name}: run failed: \{e}")
    }
    let expected = @onnx.parse_tensor_bytes(
      load_backend_bytes("\{case_name}/test_data_set_0/output_0.pb"),
    ) catch {
      e => abort("\{case_name}: output parse failed: \{e}")
    }
    let out_name = if model.graph.outputs.length() > 0 {
      model.graph.outputs[0]
    } else {
      ""
    }
    let actual = match registry.get(out_name) {
      Some(t) => t
      None => abort("\{case_name}: missing output \{out_name}")
    }
    assert_eq(actual.shape, expected.shape, msg="\{case_name} shape")
    assert_eq(
      actual.data.length(),
      expected.data.length(),
      msg="\{case_name} data length",
    )
    for i in 0..<expected.data.length() {
      let d = actual.data[i] - expected.data[i]
      assert_true(
        d < 1.0e-4 && d > -1.0e-4,
        msg="\{case_name}[ \{i}]: \{actual.data[i]} vs \{expected.data[i]}",
      )
    }
  }
}
