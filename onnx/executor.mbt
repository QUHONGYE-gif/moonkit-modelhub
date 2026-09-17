// onnx：图执行器与算子集 v1（复用 moonkit/nn）。

///|
fn attr_int(node : OnnxNode, name : String, default : Int) -> Int {
  match node.attrs.get(name) {
    Some(AttrValue::Int(v)) => v.to_int()
    _ => default
  }
}

///|
fn attr_float(node : OnnxNode, name : String, default : Double) -> Double {
  match node.attrs.get(name) {
    Some(AttrValue::Float(v)) => v
    _ => default
  }
}

///|
fn attr_ints(node : OnnxNode, name : String) -> Array[Int] {
  match node.attrs.get(name) {
    Some(AttrValue::Ints(v)) => v
    _ => []
  }
}

///|
fn get(
  registry : Map[String, @nn.Tensor],
  name : String,
) -> @nn.Tensor raise OnnxError {
  match registry.get(name) {
    Some(t) => t
    None => raise OnnxError::Parse("missing tensor: \{name}")
  }
}

///|
/// 执行单个节点，结果写入 registry。
fn execute_node(
  node : OnnxNode,
  registry : Map[String, @nn.Tensor],
) -> Unit raise OnnxError {
  let out0 = if node.outputs.length() > 0 { node.outputs[0] } else { "" }
  let inp = fn(i : Int) -> @nn.Tensor raise OnnxError {
    if i < node.inputs.length() && node.inputs[i] != "" {
      get(registry, node.inputs[i])
    } else {
      raise OnnxError::Parse("missing input \{i} for \{node.op_type}")
    }
  }
  let result = try {
    match node.op_type {
      "Gemm" => {
        let a = inp(0)
        let b = inp(1)
        let a2 = if attr_int(node, "transA", 0) == 1 {
          a.transpose(0, 1)
        } else {
          a
        }
        let b2 = if attr_int(node, "transB", 0) == 1 {
          b.transpose(0, 1)
        } else {
          b
        }
        let y = a2.matmul(b2).scale(attr_float(node, "alpha", 1.0))
        if node.inputs.length() > 2 && node.inputs[2] != "" {
          let c = inp(2).scale(attr_float(node, "beta", 1.0))
          let cols_y = y.shape[y.shape.length() - 1]
          if c.shape[c.shape.length() - 1] == cols_y &&
            (c.shape.length() == 1 || c.shape[0] == 1) {
            let bias = if c.shape.length() == 1 {
              c
            } else {
              c.reshape([cols_y])
            }
            y.add_bias(bias)
          } else {
            y.add(c)
          }
        } else {
          y
        }
      }
      "MatMul" => inp(0).matmul(inp(1))
      "Add" => inp(0).add(inp(1))
      "Relu" => inp(0).relu()
      "Sigmoid" => inp(0).sigmoid()
      "Tanh" => inp(0).tanh()
      "Softmax" => inp(0).softmax_axis(attr_int(node, "axis", -1))
      "Reshape" => {
        let x = inp(0)
        let shape_t = inp(1)
        let shape : Array[Int] = []
        for v in shape_t.data {
          let _ = shape.push(v.to_int())
        }
        x.reshape(shape)
      }
      "Flatten" => {
        let x = inp(0)
        let axis = attr_int(node, "axis", 1)
        let mut outer = 1
        for i in 0..<axis {
          outer = outer * x.shape[i]
        }
        let mut inner = 1
        for i in axis..<x.shape.length() {
          inner = inner * x.shape[i]
        }
        x.reshape([outer, inner])
      }
      "Transpose" => {
        let x = inp(0)
        let perm = attr_ints(node, "perm")
        guard perm.length() == x.shape.length() else {
          raise OnnxError::Parse("Transpose perm mismatch")
        }
        x.permute(perm)
      }
      "Concat" => {
        let axis = attr_int(node, "axis", 0)
        let mut acc = inp(0)
        for i in 1..<node.inputs.length() {
          acc = @nn.concat_2d(acc, inp(i), axis)
        }
        acc
      }
      _ => raise OnnxError::Parse("unsupported op: \{node.op_type}")
    }
  } catch {
    @nn.TensorError::ShapeMismatch(msg) => raise OnnxError::Parse(msg)
    OnnxError::Parse(msg) => raise OnnxError::Parse(msg)
    _ => raise OnnxError::Parse("op execution failed")
  }
  registry[out0] = result
}

///|
/// 执行整张图：初始器 + 输入进入注册表，按依赖反复调度直到收敛。
pub fn run_model(
  model : OnnxModel,
  inputs : Map[String, @nn.Tensor],
) -> Map[String, @nn.Tensor] raise OnnxError {
  let registry : Map[String, @nn.Tensor] = Map([])
  for (name, t) in model.graph.initializers {
    let tensor = @nn.Tensor::new(t.shape, t.data) catch {
      _ => raise OnnxError::Parse("bad initializer \{name}")
    }
    registry[name] = tensor
  }
  for (name, t) in inputs {
    registry[name] = t
  }
  let mut remaining : Array[Int] = []
  for i in 0..<model.graph.nodes.length() {
    let _ = remaining.push(i)
  }
  while !remaining.is_empty() {
    let next : Array[Int] = []
    let mut progressed = false
    for idx in remaining {
      let node = model.graph.nodes[idx]
      let mut ready = true
      for input in node.inputs {
        if input != "" && !registry.contains(input) {
          ready = false
        }
      }
      if ready {
        execute_node(node, registry)
        progressed = true
      } else {
        let _ = next.push(idx)
      }
    }
    guard progressed else { raise OnnxError::Parse("unresolved graph inputs") }
    remaining = next
  }
  registry
}
