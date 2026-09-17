// transformers：safetensors 权重解析（F32 LE）。

///|
fn read_u64_le(bytes : Bytes, offset : Int) -> UInt64 {
  let mut v : UInt64 = 0
  for i in 0..<8 {
    v = v | (bytes[offset + i].to_uint64() << (8 * i))
  }
  v
}

///|
fn read_u32_le(bytes : Bytes, offset : Int) -> UInt {
  let mut v : UInt = 0
  for i in 0..<4 {
    v = v | (bytes[offset + i].to_uint() << (8 * i))
  }
  v
}

///|
fn numel(shape : Array[Int]) -> Int {
  let mut n = 1
  for d in shape {
    n = n * d
  }
  n
}

///|
fn json_shape(j : Json?) -> Array[Int] raise @nn.TensorError {
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
    _ => raise @nn.TensorError::ShapeMismatch("missing shape")
  }
}

///|
fn json_offsets(j : Json?) -> (Int, Int) raise @nn.TensorError {
  match j {
    Some(Json::Array(items)) if items.length() == 2 => {
      let a = match items[0] {
        Json::Number(d, ..) => d.to_int()
        _ => raise @nn.TensorError::ShapeMismatch("bad data_offsets")
      }
      let b = match items[1] {
        Json::Number(d, ..) => d.to_int()
        _ => raise @nn.TensorError::ShapeMismatch("bad data_offsets")
      }
      (a, b)
    }
    _ => raise @nn.TensorError::ShapeMismatch("missing data_offsets")
  }
}

///|
/// 解析 safetensors 文件为 名称 -> Tensor 映射（仅支持 F32）。
pub fn parse_safetensors(
  bytes : Bytes,
) -> Map[String, @nn.Tensor] raise @nn.TensorError {
  guard bytes.length() >= 8 else {
    raise @nn.TensorError::ShapeMismatch("truncated safetensors")
  }
  let header_len = read_u64_le(bytes, 0).to_int()
  guard 8 + header_len <= bytes.length() else {
    raise @nn.TensorError::ShapeMismatch("truncated safetensors header")
  }
  let header_text = @utf8.decode(bytes[8:8 + header_len]) catch {
    _ =>
      raise @nn.TensorError::ShapeMismatch("invalid safetensors header UTF-8")
  }
  let header = @json.parse(header_text) catch {
    _ => raise @nn.TensorError::ShapeMismatch("invalid safetensors header JSON")
  }
  let obj = match header {
    Json::Object(o) => o
    _ =>
      raise @nn.TensorError::ShapeMismatch("safetensors header must be object")
  }
  let data_base = 8 + header_len
  let tensors : Map[String, @nn.Tensor] = Map([])
  for (name, meta) in obj {
    if name == "__metadata__" {
      continue
    }
    let meta_obj = match meta {
      Json::Object(m) => m
      _ => raise @nn.TensorError::ShapeMismatch("bad tensor entry: \{name}")
    }
    let dtype = match meta_obj.get("dtype") {
      Some(Json::String(s)) => s
      _ => raise @nn.TensorError::ShapeMismatch("missing dtype: \{name}")
    }
    guard dtype == "F32" else {
      raise @nn.TensorError::ShapeMismatch(
        "unsupported dtype \{dtype}: \{name}",
      )
    }
    let shape = json_shape(meta_obj.get("shape"))
    let offsets = json_offsets(meta_obj.get("data_offsets"))
    let count = numel(shape)
    let data : Array[Double] = []
    for i in 0..<count {
      let base = data_base + offsets.0 + i * 4
      let u = read_u32_le(bytes, base)
      let _ = data.push(Float::reinterpret_from_uint(u).to_double())
    }
    let t = @nn.Tensor::new(shape, data)
    tensors[name] = t
  }
  tensors
}
