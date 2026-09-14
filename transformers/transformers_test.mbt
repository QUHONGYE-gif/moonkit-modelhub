// transformers 黑盒测试：golden 数据来自 scripts/gen_gpt2_fixture.py（numpy）。

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
fn json_field(j : Json, key : String) -> Json? {
  match j {
    Json::Object(o) => o.get(key)
    _ => None
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
      "tests/fixtures/gpt2-model/\{name}",
      "../../tests/fixtures/gpt2-model/\{name}",
    ] {
    let bytes = @fs.read_file(candidate).binary() catch { _ => continue }
    return bytes
  }
  abort("missing fixture: \{name}")
}

///|
async fn load_json(name : String) -> Json {
  for
    candidate in [
      "tests/fixtures/gpt2-model/\{name}",
      "../../tests/fixtures/gpt2-model/\{name}",
    ] {
    let text = @fs.read_file(candidate).text() catch { _ => continue }
    return @json.parse(text) catch {
      _ => abort("invalid fixture: \{candidate}")
    }
  }
  abort("missing fixture: \{name}")
}

///|
async test "safetensors parser matches python probe" {
  let bytes = load_bytes("model.safetensors")
  let tensors = @transformers.parse_safetensors(bytes) catch {
    e => abort("parse failed: \{e}")
  }
  let probe = load_json("weight_probe.json")
  let wte = match tensors.get("transformer.wte.weight") {
    Some(t) => t
    None => abort("missing wte")
  }
  assert_eq(wte.shape, [16, 8])
  assert_true(
    (wte.data[0] - json_double(json_field(probe, "wte_00"))).abs() < 1.0e-8,
  )
  assert_true(
    (wte.data[15 * 8 + 7] - json_double(json_field(probe, "wte_last"))).abs() <
    1.0e-8,
  )
  let ln1 = match tensors.get("transformer.h.0.ln_1.weight") {
    Some(t) => t
    None => abort("missing ln_1")
  }
  assert_eq(ln1.shape, [8])
  assert_true(
    (ln1.data[0] - json_double(json_field(probe, "ln1_0"))).abs() < 1.0e-8,
  )
}

///|
async test "gpt2 forward matches numpy" {
  let config_json = load_json("config.json")
  let config = @transformers.parse_config(config_json) catch {
    e => abort("config failed: \{e}")
  }
  let tensors = @transformers.parse_safetensors(load_bytes("model.safetensors")) catch {
    e => abort("parse failed: \{e}")
  }
  let model = @transformers.Gpt2Model::load(config, tensors) catch {
    e => abort("load failed: \{e}")
  }
  let expected_json = load_json("expected_logits.json")
  let ids = json_ints(json_field(expected_json, "input_ids"))
  let expected = json_doubles(json_field(expected_json, "expected"))
  let logits = model.forward(ids) catch { e => abort("forward failed: \{e}") }
  assert_eq(logits.shape, [1, 4, 16])
  assert_eq(logits.data.length(), expected.length())
  for i in 0..<expected.length() {
    let d = logits.data[i] - expected[i]
    assert_true(d < 1.0e-4 && d > -1.0e-4)
  }
}

///|
async test "greedy generation matches numpy" {
  let config = @transformers.parse_config(load_json("config.json")) catch {
    e => abort("config failed: \{e}")
  }
  let tensors = @transformers.parse_safetensors(load_bytes("model.safetensors")) catch {
    e => abort("parse failed: \{e}")
  }
  let model = @transformers.Gpt2Model::load(config, tensors) catch {
    e => abort("load failed: \{e}")
  }
  let gen = @transformers.Generator::new(model)
  let expected_json = load_json("expected_generation.json")
  let prompt = json_ints(json_field(expected_json, "input_ids"))
  let expected = json_ints(json_field(expected_json, "expected"))
  let got = gen.generate(prompt, 5, 0.0) catch {
    e => abort("generate failed: \{e}")
  }
  assert_eq(got, expected)
}

///|
async test "incremental step logits equal full forward" {
  let config = @transformers.parse_config(load_json("config.json")) catch {
    e => abort("config failed: \{e}")
  }
  let tensors = @transformers.parse_safetensors(load_bytes("model.safetensors")) catch {
    e => abort("parse failed: \{e}")
  }
  let model = @transformers.Gpt2Model::load(config, tensors) catch {
    e => abort("load failed: \{e}")
  }
  let full = model.forward([1, 2]) catch { e => abort("forward failed: \{e}") }
  let gen = @transformers.Generator::new(model)
  let l1 = gen.step(1) catch { e => abort("step1: \{e}") }
  let l2 = gen.step(2) catch { e => abort("step2: \{e}") }
  for i in 0..<16 {
    let a = full.data[i]
    let b = l1.data[i]
    assert_true((a - b).abs() < 1.0e-6, msg="token1 logit \{i}: \{a} vs \{b}")
  }
  for i in 0..<16 {
    let a = full.data[16 + i]
    let b = l2.data[i]
    assert_true((a - b).abs() < 1.0e-6, msg="token2 logit \{i}: \{a} vs \{b}")
  }
}
