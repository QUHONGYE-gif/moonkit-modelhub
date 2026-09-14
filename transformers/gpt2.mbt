// transformers：GPT-2 模型加载与前向。

///|
pub struct Gpt2Block {
  ln1_w : @nn.Tensor
  ln1_b : @nn.Tensor?
  qkv_w : @nn.Tensor
  qkv_b : @nn.Tensor?
  proj_w : @nn.Tensor
  proj_b : @nn.Tensor?
  ln2_w : @nn.Tensor
  ln2_b : @nn.Tensor?
  fc_w : @nn.Tensor
  fc_b : @nn.Tensor?
  fc_proj_w : @nn.Tensor
  fc_proj_b : @nn.Tensor?
}

///|
pub struct Gpt2Model {
  config : Gpt2Config
  direct : Bool
  wte : @nn.Tensor
  wpe : @nn.Tensor
  blocks : Array[Gpt2Block]
  ln_f_w : @nn.Tensor
  ln_f_b : @nn.Tensor?
  lm_head : @nn.Tensor
}

///|
fn require(
  weights : Map[String, @nn.Tensor],
  name : String,
) -> @nn.Tensor raise @nn.TensorError {
  match weights.get(name) {
    Some(t) => t
    None => raise @nn.TensorError::ShapeMismatch("missing weight: \{name}")
  }
}

///|
/// 从 safetensors 权重表加载 GPT-2 模型（lm_head 缺失时与 wte 权重绑定）。
pub fn Gpt2Model::load(
  config : Gpt2Config,
  weights : Map[String, @nn.Tensor],
) -> Gpt2Model raise @nn.TensorError {
  let wte = require(weights, "transformer.wte.weight")
  let wpe = require(weights, "transformer.wpe.weight")
  let qkv0 = require(weights, "transformer.h.0.attn.c_attn.weight")
  let direct = qkv0.shape[0] == config.n_embd
  let blocks : Array[Gpt2Block] = []
  for i in 0..<config.n_layer {
    let p = "transformer.h.\{i}"
    let block = {
      ln1_w: require(weights, "\{p}.ln_1.weight"),
      ln1_b: weights.get("\{p}.ln_1.bias"),
      qkv_w: require(weights, "\{p}.attn.c_attn.weight"),
      qkv_b: weights.get("\{p}.attn.c_attn.bias"),
      proj_w: require(weights, "\{p}.attn.c_proj.weight"),
      proj_b: weights.get("\{p}.attn.c_proj.bias"),
      ln2_w: require(weights, "\{p}.ln_2.weight"),
      ln2_b: weights.get("\{p}.ln_2.bias"),
      fc_w: require(weights, "\{p}.mlp.c_fc.weight"),
      fc_b: weights.get("\{p}.mlp.c_fc.bias"),
      fc_proj_w: require(weights, "\{p}.mlp.c_proj.weight"),
      fc_proj_b: weights.get("\{p}.mlp.c_proj.bias"),
    }
    let _ = blocks.push(block)
  }
  let ln_f_w = require(weights, "transformer.ln_f.weight")
  let lm_head = match weights.get("lm_head.weight") {
    Some(t) => t
    None => wte
  }
  {
    config,
    direct,
    wte,
    wpe,
    blocks,
    ln_f_w,
    ln_f_b: weights.get("transformer.ln_f.bias"),
    lm_head,
  }
}

///|
fn linear(
  x : @nn.Tensor,
  w : @nn.Tensor,
  b : @nn.Tensor?,
  direct : Bool,
) -> @nn.Tensor raise @nn.TensorError {
  let wt = if direct { w } else { w.transpose(0, 1) }
  let y = x.matmul(wt)
  match b {
    Some(bias) => y.add_bias(bias)
    None => y
  }
}

///|
fn layer_norm(
  x : @nn.Tensor,
  w : @nn.Tensor,
  b : @nn.Tensor?,
  eps : Double,
) -> @nn.Tensor raise @nn.TensorError {
  x.layer_norm(Some(w), b, eps)
}

///|
/// 把 qkv 结果切成 q/k/v 三段（各 [1,1,D]）。
fn take_third(
  src : @nn.Tensor,
  offset : Int,
) -> @nn.Tensor raise @nn.TensorError {
  let d = src.shape[2] / 3
  let data : Array[Double] = []
  for j in 0..<d {
    let _ = data.push(src.data[offset * d + j])
  }
  @nn.Tensor::new([1, 1, d], data)
}

///|
/// 把 [1,T,3D] 的 qkv 结果切成第 offset 段（[1,T,D]）。
fn take_third_seq(
  src : @nn.Tensor,
  offset : Int,
) -> @nn.Tensor raise @nn.TensorError {
  let t = src.shape[1]
  let d = src.shape[2] / 3
  let data : Array[Double] = []
  for i in 0..<t {
    for j in 0..<d {
      let _ = data.push(src.data[i * (3 * d) + offset * d + j])
    }
  }
  @nn.Tensor::new([1, t, d], data)
}

///|
/// 完整前向：input_ids [T] -> logits [1,T,vocab]。
pub fn Gpt2Model::forward(
  self : Gpt2Model,
  input_ids : Array[Int],
) -> @nn.Tensor raise @nn.TensorError {
  let t = input_ids.length()
  let d = self.config.n_embd
  let data : Array[Double] = []
  for i in 0..<t {
    let tok = input_ids[i]
    for j in 0..<d {
      let _ = data.push(self.wte.data[tok * d + j] + self.wpe.data[i * d + j])
    }
  }
  let mut x = @nn.Tensor::new([1, t, d], data)
  for block in self.blocks {
    x = apply_block(block, x, self.config, self.direct)
  }
  let h = layer_norm(x, self.ln_f_w, self.ln_f_b, self.config.eps)
  h.matmul(self.lm_head.transpose(0, 1))
}

///|
fn apply_block(
  block : Gpt2Block,
  x : @nn.Tensor,
  config : Gpt2Config,
  direct : Bool,
) -> @nn.Tensor raise @nn.TensorError {
  let t = x.shape[1]
  let d = config.n_embd
  let ln1 = layer_norm(x, block.ln1_w, block.ln1_b, config.eps)
  let qkv = linear(ln1, block.qkv_w, block.qkv_b, direct)
  let dh = d / config.n_head
  let q = take_third_seq(qkv, 0)
    .reshape([1, t, config.n_head, dh])
    .transpose(1, 2)
    .reshape([config.n_head, t, dh])
  let k = take_third_seq(qkv, 1)
    .reshape([1, t, config.n_head, dh])
    .transpose(1, 2)
    .reshape([config.n_head, t, dh])
  let v = take_third_seq(qkv, 2)
    .reshape([1, t, config.n_head, dh])
    .transpose(1, 2)
    .reshape([config.n_head, t, dh])
  let attn = @nn.attention(q, k, v, true)
    .reshape([1, config.n_head, t, dh])
    .transpose(1, 2)
    .reshape([1, t, d])
  let x = x.add(linear(attn, block.proj_w, block.proj_b, direct))
  let ln2 = layer_norm(x, block.ln2_w, block.ln2_b, config.eps)
  let mlp = linear(ln2, block.fc_w, block.fc_b, direct).gelu()
  x.add(linear(mlp, block.fc_proj_w, block.fc_proj_b, direct))
}
