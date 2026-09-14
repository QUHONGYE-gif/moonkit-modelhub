// moonkit/nn 黑盒测试：golden 数据来自 scripts/gen_nn_golden.py（numpy）。

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
fn json_bool(j : Json?) -> Bool {
  match j {
    Some(Json::True) => true
    _ => false
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
fn json_int(j : Json?) -> Int {
  match j {
    Some(Json::Number(d, ..)) => d.to_int()
    _ => 0
  }
}

///|
async fn load_fixture(name : String) -> Json {
  for
    candidate in [
      "tests/fixtures/nn/\{name}.json",
      "../../tests/fixtures/nn/\{name}.json",
    ] {
    let text = @fs.read_file(candidate).text() catch { _ => continue }
    return @json.parse(text) catch {
      _ => abort("invalid fixture: \{candidate}")
    }
  }
  abort("missing fixture: \{name}")
}

///|
fn assert_close(
  actual : @nn.Tensor,
  expected_shape : Array[Int],
  expected : Array[Double],
  tol : Double,
) -> Unit raise Error {
  assert_eq(actual.shape, expected_shape)
  assert_eq(actual.data.length(), expected.length())
  for i in 0..<expected.length() {
    let d = actual.data[i] - expected[i]
    assert_true(d <= tol && d >= -tol)
  }
}

///|
async test "reshape matches numpy" {
  let j = load_fixture("reshape")
  let t = @nn.Tensor::new(
    json_ints(json_field(j, "shape")),
    json_doubles(json_field(j, "data")),
  ) catch {
    e => abort("bad fixture: \{e}")
  }
  let r = t.reshape(json_ints(json_field(j, "new_shape"))) catch {
    e => abort("reshape failed: \{e}")
  }
  assert_close(
    r,
    json_ints(json_field(j, "expected_shape")),
    json_doubles(json_field(j, "expected")),
    1.0e-5,
  )
}

///|
async test "transpose matches numpy" {
  let j = load_fixture("transpose")
  let t = @nn.Tensor::new(
    json_ints(json_field(j, "shape")),
    json_doubles(json_field(j, "data")),
  ) catch {
    e => abort("bad fixture: \{e}")
  }
  assert_close(
    t.transpose(0, 1),
    json_ints(json_field(j, "expected_shape")),
    json_doubles(json_field(j, "expected")),
    1.0e-5,
  )
}

///|
async test "elementwise add/sub/mul/scale match numpy" {
  let j = load_fixture("add")
  let shape = json_ints(json_field(j, "shape"))
  let a = @nn.Tensor::new(shape, json_doubles(json_field(j, "a"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let b = @nn.Tensor::new(shape, json_doubles(json_field(j, "b"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let add = a.add(b) catch { e => abort("add: \{e}") }
  assert_close(add, shape, json_doubles(json_field(j, "expected")), 1.0e-5)

  let js = load_fixture("sub")
  let sub = a.sub(b) catch { e => abort("sub: \{e}") }
  assert_close(sub, shape, json_doubles(json_field(js, "expected")), 1.0e-5)

  let jm = load_fixture("mul")
  let mul = a.mul(b) catch { e => abort("mul: \{e}") }
  assert_close(mul, shape, json_doubles(json_field(jm, "expected")), 1.0e-5)

  let jsc = load_fixture("scale")
  let scaled = a.scale(json_double(json_field(jsc, "s")))
  assert_close(scaled, shape, json_doubles(json_field(jsc, "expected")), 1.0e-5)
}

///|
async test "gemm matches numpy" {
  let j = load_fixture("gemm")
  let a = @nn.Tensor::new(
    json_ints(json_field(j, "a_shape")),
    json_doubles(json_field(j, "a")),
  ) catch {
    e => abort("bad fixture: \{e}")
  }
  let b = @nn.Tensor::new(
    json_ints(json_field(j, "b_shape")),
    json_doubles(json_field(j, "b")),
  ) catch {
    e => abort("bad fixture: \{e}")
  }
  let out = a.matmul(b) catch { e => abort("matmul: \{e}") }
  assert_close(
    out,
    json_ints(json_field(j, "expected_shape")),
    json_doubles(json_field(j, "expected")),
    1.0e-4,
  )
}

///|
async test "batch gemm matches numpy" {
  let j = load_fixture("gemm_batch")
  let a = @nn.Tensor::new(
    json_ints(json_field(j, "a_shape")),
    json_doubles(json_field(j, "a")),
  ) catch {
    e => abort("bad fixture: \{e}")
  }
  let b = @nn.Tensor::new(
    json_ints(json_field(j, "b_shape")),
    json_doubles(json_field(j, "b")),
  ) catch {
    e => abort("bad fixture: \{e}")
  }
  let out = a.matmul(b) catch { e => abort("matmul: \{e}") }
  assert_close(
    out,
    json_ints(json_field(j, "expected_shape")),
    json_doubles(json_field(j, "expected")),
    1.0e-4,
  )
}

///|
async test "gelu matches numpy" {
  let j = load_fixture("gelu")
  let t = @nn.Tensor::new(
    json_ints(json_field(j, "shape")),
    json_doubles(json_field(j, "data")),
  ) catch {
    e => abort("bad fixture: \{e}")
  }
  assert_close(
    t.gelu(),
    json_ints(json_field(j, "shape")),
    json_doubles(json_field(j, "expected")),
    1.0e-5,
  )
}

///|
async test "softmax matches numpy and is stable" {
  let j = load_fixture("softmax")
  let shape = json_ints(json_field(j, "shape"))
  let t = @nn.Tensor::new(shape, json_doubles(json_field(j, "data"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let out = t.softmax() catch { e => abort("softmax: \{e}") }
  assert_close(out, shape, json_doubles(json_field(j, "expected")), 1.0e-5)
}

///|
async test "layer norm and rms norm match numpy" {
  let j = load_fixture("layernorm")
  let shape = json_ints(json_field(j, "shape"))
  let t = @nn.Tensor::new(shape, json_doubles(json_field(j, "data"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let w = @nn.Tensor::new([shape[1]], json_doubles(json_field(j, "weight"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let bb = @nn.Tensor::new([shape[1]], json_doubles(json_field(j, "bias"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let out = t.layer_norm(Some(w), Some(bb), json_double(json_field(j, "eps"))) catch {
    e => abort("layernorm: \{e}")
  }
  assert_close(out, shape, json_doubles(json_field(j, "expected")), 1.0e-5)

  let jr = load_fixture("rmsnorm")
  let t2 = @nn.Tensor::new(shape, json_doubles(json_field(jr, "data"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let w2 = @nn.Tensor::new([shape[1]], json_doubles(json_field(jr, "weight"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let out2 = t2.rms_norm(Some(w2), json_double(json_field(jr, "eps"))) catch {
    e => abort("rmsnorm: \{e}")
  }
  assert_close(out2, shape, json_doubles(json_field(jr, "expected")), 1.0e-5)
}

///|
async test "attention matches numpy" {
  let j = load_fixture("attention")
  let b = json_int(json_field(j, "b"))
  let tq = json_int(json_field(j, "tq"))
  let tk = json_int(json_field(j, "tk"))
  let d = json_int(json_field(j, "d"))
  let q = @nn.Tensor::new([b, tq, d], json_doubles(json_field(j, "q"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let k = @nn.Tensor::new([b, tk, d], json_doubles(json_field(j, "k"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let v = @nn.Tensor::new([b, tk, d], json_doubles(json_field(j, "v"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let out = @nn.attention(q, k, v, json_bool(json_field(j, "causal"))) catch {
    e => abort("attention: \{e}")
  }
  assert_close(
    out,
    json_ints(json_field(j, "expected_shape")),
    json_doubles(json_field(j, "expected")),
    1.0e-4,
  )
}

///|
async test "causal attention masks future positions" {
  let j = load_fixture("attention_causal")
  let b = json_int(json_field(j, "b"))
  let tq = json_int(json_field(j, "tq"))
  let tk = json_int(json_field(j, "tk"))
  let d = json_int(json_field(j, "d"))
  let q = @nn.Tensor::new([b, tq, d], json_doubles(json_field(j, "q"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let k = @nn.Tensor::new([b, tk, d], json_doubles(json_field(j, "k"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let v = @nn.Tensor::new([b, tk, d], json_doubles(json_field(j, "v"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let out = @nn.attention(q, k, v, true) catch { e => abort("attention: \{e}") }
  assert_close(
    out,
    json_ints(json_field(j, "expected_shape")),
    json_doubles(json_field(j, "expected")),
    1.0e-4,
  )
}

///|
async test "kv cache incremental equals full forward" {
  let j = load_fixture("kv_cache")
  let b = json_int(json_field(j, "b"))
  let tq2 = json_int(json_field(j, "tq2"))
  let d = json_int(json_field(j, "d"))
  let q2 = @nn.Tensor::new([b, tq2, d], json_doubles(json_field(j, "q2"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let k1 = @nn.Tensor::new([b, 3, d], json_doubles(json_field(j, "k1"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let v1 = @nn.Tensor::new([b, 3, d], json_doubles(json_field(j, "v1"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let k2 = @nn.Tensor::new([b, 3, d], json_doubles(json_field(j, "k2"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let v2 = @nn.Tensor::new([b, 3, d], json_doubles(json_field(j, "v2"))) catch {
    e => abort("bad fixture: \{e}")
  }
  let k_full = @nn.cat_seq(k1, k2) catch { e => abort("cat: \{e}") }
  let v_full = @nn.cat_seq(v1, v2) catch { e => abort("cat: \{e}") }
  let out = @nn.attention(q2, k_full, v_full, true) catch {
    e => abort("attention: \{e}")
  }
  assert_close(
    out,
    json_ints(json_field(j, "expected_shape")),
    json_doubles(json_field(j, "expected")),
    1.0e-4,
  )
}

///|
test "randn is deterministic per seed" {
  let a = @nn.Tensor::randn([8], 42UL)
  let b = @nn.Tensor::randn([8], 42UL)
  assert_eq(a.data, b.data)
  let c = @nn.Tensor::randn([8], 43UL)
  assert_true(a.data != c.data)
}
