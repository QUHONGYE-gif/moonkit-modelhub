// transformers：KV cache 增量生成（贪心 + 温度采样）。

///|
pub struct BlockCache {
  k : @nn.Tensor
  v : @nn.Tensor
}

///|
pub struct Generator {
  model : Gpt2Model
  caches : Array[BlockCache]
  pos : Ref[Int]
  rng : Ref[UInt64]
}

///|
pub fn Generator::new(model : Gpt2Model) -> Generator {
  let caches : Array[BlockCache] = []
  for i in 0..<model.config.n_layer {
    let _ = caches.push({
      k: @nn.Tensor::zeros([1, 0, model.config.n_embd]),
      v: @nn.Tensor::zeros([1, 0, model.config.n_embd]),
    })
  }
  { model, caches, pos: { val: 0, }, rng: { val: 0x9E3779B97F4A7C15UL, }, }
}

///|
fn argmax(data : Array[Double]) -> Int {
  let mut best = 0
  for i in 1..<data.length() {
    if data[i] > data[best] {
      best = i
    }
  }
  best
}

///|
fn sample_uniform(rng : Ref[UInt64]) -> Double {
  rng.val = rng.val * 6364136223846793005UL + 1442695040888963407UL
  (rng.val >> 11).to_double() / 9.007199254740992e15
}

///|
fn sample_token(
  logits : @nn.Tensor,
  temperature : Double,
  rng : Ref[UInt64],
) -> Int raise @nn.TensorError {
  if temperature <= 0.0 {
    argmax(logits.data)
  } else {
    let probs = logits.scale(1.0 / temperature).softmax()
    let u = sample_uniform(rng)
    let mut cum = 0.0
    for i in 0..<probs.data.length() {
      cum = cum + probs.data[i]
      if u < cum {
        return i
      }
    }
    probs.data.length() - 1
  }
}

///|
/// 单步增量前向：给定 token 与已缓存的 K/V，返回 [1,1,vocab] logits。
pub fn Generator::step(
  self : Generator,
  token : Int,
) -> @nn.Tensor raise @nn.TensorError {
  let d = self.model.config.n_embd
  let data : Array[Double] = []
  for j in 0..<d {
    let _ = data.push(
      self.model.wte.data[token * d + j] +
      self.model.wpe.data[self.pos.val * d + j],
    )
  }
  let mut x = @nn.Tensor::new([1, 1, d], data)
  let n_head = self.model.config.n_head
  let dh = d / n_head
  for i in 0..<self.caches.length() {
    let block = self.model.blocks[i]
    let ln1 = layer_norm(x, block.ln1_w, block.ln1_b, self.model.config.eps)
    let qkv = linear(ln1, block.qkv_w, block.qkv_b, self.model.direct)
    let q = take_third(qkv, 0)
      .reshape([1, 1, n_head, dh])
      .transpose(1, 2)
      .reshape([n_head, 1, dh])
    let k_new = take_third(qkv, 1)
    let v_new = take_third(qkv, 2)
    let kc = if self.pos.val == 0 {
      k_new
    } else {
      @nn.cat_seq(self.caches[i].k, k_new)
    }
    let vc = if self.pos.val == 0 {
      v_new
    } else {
      @nn.cat_seq(self.caches[i].v, v_new)
    }
    let tk = kc.shape[1]
    let kc_h = kc
      .reshape([1, tk, n_head, dh])
      .transpose(1, 2)
      .reshape([n_head, tk, dh])
    let vc_h = vc
      .reshape([1, tk, n_head, dh])
      .transpose(1, 2)
      .reshape([n_head, tk, dh])
    let attn = @nn.attention(q, kc_h, vc_h, false)
      .reshape([1, n_head, 1, dh])
      .transpose(1, 2)
      .reshape([1, 1, d])
    x = x.add(linear(attn, block.proj_w, block.proj_b, self.model.direct))
    let ln2 = layer_norm(x, block.ln2_w, block.ln2_b, self.model.config.eps)
    let mlp = linear(ln2, block.fc_w, block.fc_b, self.model.direct).gelu()
    x = x.add(linear(mlp, block.fc_proj_w, block.fc_proj_b, self.model.direct))
    self.caches[i] = { k: kc, v: vc, }
  }
  let h = layer_norm(
    x,
    self.model.ln_f_w,
    self.model.ln_f_b,
    self.model.config.eps,
  )
  self.pos.val = self.pos.val + 1
  h.matmul(self.model.lm_head.transpose(0, 1))
}

///|
/// 生成：先喂 prompt 建立 cache，再逐 token 采样直到 max_new 或 EOS。
pub fn Generator::generate(
  self : Generator,
  prompt : Array[Int],
  max_new : Int,
  temperature : Double,
) -> Array[Int] raise @nn.TensorError {
  let ids = prompt.copy()
  let mut logits = @nn.Tensor::zeros([1, 1, self.model.config.vocab_size])
  for i in 0..<prompt.length() {
    logits = self.step(prompt[i])
  }
  for _i in 0..<max_new {
    let next = sample_token(logits, temperature, self.rng)
    if next == self.model.config.eos_token_id {
      break
    }
    let _ = ids.push(next)
    logits = self.step(next)
  }
  ids
}
