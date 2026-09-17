// onnx：protobuf wire 解析与 ONNX 模型结构（MVP 子集）。

///|
pub(all) suberror OnnxError {
  Parse(String)
} derive(@debug.Debug)

///|
pub impl Show for OnnxError with fn output(self, logger) {
  match self {
    Parse(msg) => logger.write_string(msg)
  }
}

///|
pub struct ProtoReader {
  bytes : BytesView
  pos : Ref[Int]
}

///|
fn ProtoReader::new(bytes : Bytes) -> ProtoReader {
  { bytes: bytes[:], pos: { val: 0, }, }
}

///|
fn ProtoReader::from_view(bytes : BytesView) -> ProtoReader {
  { bytes, pos: { val: 0, }, }
}

///|
fn read_byte(r : ProtoReader) -> Byte raise OnnxError {
  guard r.pos.val < r.bytes.length() else {
    raise OnnxError::Parse("truncated protobuf")
  }
  let b = r.bytes[r.pos.val]
  r.pos.val = r.pos.val + 1
  b
}

///|
fn read_varint(r : ProtoReader) -> UInt64 raise OnnxError {
  let mut v : UInt64 = 0
  let mut shift = 0
  while true {
    let b = read_byte(r).to_uint64()
    v = v | ((b & 0x7f) << shift)
    if (b & 0x80) == 0 {
      return v
    }
    shift = shift + 7
    guard shift < 64 else { raise OnnxError::Parse("varint too long") }
  }
  abort("unreachable")
}

///|
/// 读取字段键：(字段号, wire type)。
fn read_key(r : ProtoReader) -> (Int, Int) raise OnnxError {
  let key = read_varint(r).to_int()
  (key / 8, key % 8)
}

///|
fn skip_bytes(r : ProtoReader, n : Int) -> Unit raise OnnxError {
  guard r.pos.val + n <= r.bytes.length() else {
    raise OnnxError::Parse("truncated protobuf")
  }
  r.pos.val = r.pos.val + n
}

///|
fn skip_field(r : ProtoReader, wire : Int) -> Unit raise OnnxError {
  match wire {
    0 => {
      let _ = read_varint(r)
    }
    1 => skip_bytes(r, 8)
    2 => {
      let len = read_varint(r).to_int()
      skip_bytes(r, len)
    }
    5 => skip_bytes(r, 4)
    _ => raise OnnxError::Parse("bad wire type \{wire}")
  }
}

///|
fn read_len_view(r : ProtoReader) -> BytesView raise OnnxError {
  let len = read_varint(r).to_int()
  guard r.pos.val + len <= r.bytes.length() else {
    raise OnnxError::Parse("truncated protobuf")
  }
  let view = r.bytes[r.pos.val:r.pos.val + len]
  r.pos.val = r.pos.val + len
  view
}

///|
fn read_string(r : ProtoReader) -> String raise OnnxError {
  let view = read_len_view(r)
  @utf8.decode(view) catch {
    _ => raise OnnxError::Parse("bad UTF-8 string")
  }
}

///|
fn read_u32(r : ProtoReader) -> UInt raise OnnxError {
  let b0 = read_byte(r).to_uint()
  let b1 = read_byte(r).to_uint()
  let b2 = read_byte(r).to_uint()
  let b3 = read_byte(r).to_uint()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn read_u64(r : ProtoReader) -> UInt64 raise OnnxError {
  let mut v : UInt64 = 0
  for i in 0..<8 {
    v = v | (read_byte(r).to_uint64() << (8 * i))
  }
  v
}

///|
/// 读取 packed repeated float（4 字节 LE），转成 Double 数组。
fn read_packed_f32(r : ProtoReader) -> Array[Double] raise OnnxError {
  let view = read_len_view(r)
  guard view.length() % 4 == 0 else {
    raise OnnxError::Parse("bad packed float length")
  }
  let out : Array[Double] = []
  let mut i = 0
  while i < view.length() {
    let u = view[i].to_uint() |
      (view[i + 1].to_uint() << 8) |
      (view[i + 2].to_uint() << 16) |
      (view[i + 3].to_uint() << 24)
    let _ = out.push(Float::reinterpret_from_uint(u).to_double())
    i = i + 4
  }
  out
}

///|
/// 读取 packed repeated varint（如 dims / int64_data）。
fn read_packed_varints(r : ProtoReader) -> Array[Int64] raise OnnxError {
  let view = read_len_view(r)
  let sub = ProtoReader::from_view(view)
  let out : Array[Int64] = []
  while sub.pos.val < sub.bytes.length() {
    let _ = out.push(read_varint(sub).reinterpret_as_int64())
  }
  out
}

///|
pub enum AttrValue {
  Int(Int64)
  Float(Double)
  Str(String)
  Ints(Array[Int])
} derive(@debug.Debug)

///|
pub struct OnnxNode {
  inputs : Array[String]
  outputs : Array[String]
  op_type : String
  attrs : Map[String, AttrValue]
} derive(@debug.Debug)

///|
pub struct OnnxTensor {
  name : String
  shape : Array[Int]
  data : Array[Double]
} derive(@debug.Debug)

///|
pub struct OnnxGraph {
  nodes : Array[OnnxNode]
  initializers : Map[String, OnnxTensor]
  inputs : Array[String]
  outputs : Array[String]
} derive(@debug.Debug)

///|
pub struct OnnxModel {
  ir_version : Int64
  opset : Int64
  graph : OnnxGraph
} derive(@debug.Debug)

///|
fn parse_attribute(view : BytesView) -> (String, AttrValue) raise OnnxError {
  let r = ProtoReader::from_view(view)
  let mut name = ""
  let mut attr_type = 0
  let mut i_val : Int64 = 0
  let mut f_val : Double = 0.0
  let mut s_val = ""
  let ints_val : Array[Int] = []
  while r.pos.val < r.bytes.length() {
    let (field, wire) = read_key(r)
    match field {
      1 => name = read_string(r)
      2 => f_val = Float::reinterpret_from_uint(read_u32(r)).to_double()
      3 => i_val = read_varint(r).reinterpret_as_int64()
      4 => s_val = read_string(r)
      8 =>
        if wire == 2 {
          for v in read_packed_varints(r) {
            let _ = ints_val.push(v.to_int())
          }
        } else {
          let _ = ints_val.push(read_varint(r).to_int())
        }
      20 => attr_type = read_varint(r).to_int()
      _ => skip_field(r, wire)
    }
  }
  let value = match attr_type {
    2 => AttrValue::Int(i_val)
    3 => AttrValue::Str(s_val)
    7 => AttrValue::Ints(ints_val)
    _ => AttrValue::Float(f_val)
  }
  (name, value)
}

///|
fn parse_node(view : BytesView) -> OnnxNode raise OnnxError {
  let r = ProtoReader::from_view(view)
  let inputs : Array[String] = []
  let outputs : Array[String] = []
  let mut op_type = ""
  let attrs : Map[String, AttrValue] = Map([])
  while r.pos.val < r.bytes.length() {
    let (field, wire) = read_key(r)
    match field {
      1 => {
        let _ = inputs.push(read_string(r))
      }
      2 => {
        let _ = outputs.push(read_string(r))
      }
      4 => op_type = read_string(r)
      5 => {
        let view5 = read_len_view(r)
        let (name, value) = parse_attribute(view5)
        attrs[name] = value
      }
      _ => skip_field(r, wire)
    }
  }
  { inputs, outputs, op_type, attrs, }
}

///|
fn parse_tensor(view : BytesView) -> OnnxTensor raise OnnxError {
  let r = ProtoReader::from_view(view)
  let dims : Array[Int64] = []
  let mut data_type = 0
  let mut name = ""
  let mut data : Array[Double] = []
  while r.pos.val < r.bytes.length() {
    let (field, wire) = read_key(r)
    match field {
      1 =>
        if wire == 2 {
          for d in read_packed_varints(r) {
            let _ = dims.push(d)
          }
        } else {
          let _ = dims.push(read_varint(r).reinterpret_as_int64())
        }
      2 => data_type = read_varint(r).to_int()
      3 =>
        if wire == 2 {
          for d in read_packed_varints(r) {
            let _ = data.push(d.to_double())
          }
        } else {
          let _ = data.push(read_varint(r).reinterpret_as_int64().to_double())
        }
      4 =>
        if wire == 2 {
          data = read_packed_f32(r)
        } else {
          let _ = data.push(
            Float::reinterpret_from_uint(read_u32(r)).to_double(),
          )
        }
      8 => name = read_string(r)
      9 => {
        // raw_data：FLOAT 为 4 字节 LE，INT64 为 8 字节 LE
        let raw = read_len_view(r)
        data = []
        let sub = ProtoReader::from_view(raw)
        if data_type == 1 {
          guard raw.length() % 4 == 0 else {
            raise OnnxError::Parse("bad raw_data length")
          }
          while sub.pos.val < sub.bytes.length() {
            let u = read_u32(sub)
            let _ = data.push(Float::reinterpret_from_uint(u).to_double())
          }
        } else if data_type == 7 {
          guard raw.length() % 8 == 0 else {
            raise OnnxError::Parse("bad raw_data length")
          }
          while sub.pos.val < sub.bytes.length() {
            let v = read_u64(sub)
            let _ = data.push(v.reinterpret_as_int64().to_double())
          }
        } else {
          raise OnnxError::Parse("unsupported raw_data dtype \{data_type}")
        }
      }
      _ => skip_field(r, wire)
    }
  }
  let shape : Array[Int] = []
  for d in dims {
    let _ = shape.push(d.to_int())
  }
  { name, shape, data, }
}

///|
fn parse_opset(view : BytesView) -> Int64 raise OnnxError {
  let r = ProtoReader::from_view(view)
  let mut version : Int64 = 0
  while r.pos.val < r.bytes.length() {
    let (field, wire) = read_key(r)
    match field {
      2 => version = read_varint(r).reinterpret_as_int64()
      _ => skip_field(r, wire)
    }
  }
  version
}

///|
/// ValueInfoProto：取 name 字段。
fn parse_value_info(view : BytesView) -> String raise OnnxError {
  let r = ProtoReader::from_view(view)
  let mut name = ""
  while r.pos.val < r.bytes.length() {
    let (field, wire) = read_key(r)
    match field {
      1 => name = read_string(r)
      _ => skip_field(r, wire)
    }
  }
  name
}

///|
fn parse_graph(view : BytesView) -> OnnxGraph raise OnnxError {
  let r = ProtoReader::from_view(view)
  let nodes : Array[OnnxNode] = []
  let initializers : Map[String, OnnxTensor] = Map([])
  let inputs : Array[String] = []
  let outputs : Array[String] = []
  while r.pos.val < r.bytes.length() {
    let (field, wire) = read_key(r)
    match field {
      1 => {
        let view1 = read_len_view(r)
        let _ = nodes.push(parse_node(view1))
      }
      5 => {
        let view5 = read_len_view(r)
        let t = parse_tensor(view5)
        initializers[t.name] = t
      }
      11 => {
        let view11 = read_len_view(r)
        let _ = inputs.push(parse_value_info(view11))
      }
      12 => {
        let view12 = read_len_view(r)
        let _ = outputs.push(parse_value_info(view12))
      }
      _ => skip_field(r, wire)
    }
  }
  { nodes, initializers, inputs, outputs, }
}

///|
/// 解析 ONNX ModelProto（MVP 子集）。
pub fn parse_model(bytes : Bytes) -> OnnxModel raise OnnxError {
  let r = ProtoReader::new(bytes)
  let mut ir_version : Int64 = 0
  let mut opset : Int64 = 0
  let mut graph : OnnxGraph? = None
  while r.pos.val < r.bytes.length() {
    let (field, wire) = read_key(r)
    match field {
      1 => ir_version = read_varint(r).reinterpret_as_int64()
      7 => {
        let view7 = read_len_view(r)
        graph = Some(parse_graph(view7))
      }
      8 => {
        let view8 = read_len_view(r)
        let v = parse_opset(view8)
        if opset == 0 {
          opset = v
        }
      }
      _ => skip_field(r, wire)
    }
  }
  match graph {
    Some(g) => { ir_version, opset, graph: g, }
    None => raise OnnxError::Parse("missing graph")
  }
}

///|
/// 解析独立的 TensorProto（用于 backend test 的 input/output .pb）。
pub fn parse_tensor_bytes(bytes : Bytes) -> OnnxTensor raise OnnxError {
  parse_tensor(bytes[:])
}
