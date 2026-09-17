// moonkit/nn：注意力与 KV cache。

///|
/// scaled dot-product attention（单头）：q [B,Tq,d]，k/v [B,Tk,d]。
/// causal=true 时掩码未来位置（-1e300）。
pub fn attention(
  q : Tensor,
  k : Tensor,
  v : Tensor,
  causal : Bool,
) -> Tensor raise TensorError {
  guard q.shape.length() == 3 && k.shape.length() == 3 && v.shape.length() == 3 else {
    raise TensorError::ShapeMismatch("attention expects 3D inputs")
  }
  guard q.shape[0] == k.shape[0] &&
    k.shape[0] == v.shape[0] &&
    q.shape[2] == k.shape[2] &&
    k.shape[1] == v.shape[1] else {
    raise TensorError::ShapeMismatch("attention shapes mismatch")
  }
  let b = q.shape[0]
  let tq = q.shape[1]
  let tk = k.shape[1]
  let d = q.shape[2]
  let scale = 1.0 / @math.pow(d.to_double(), 0.5)
  let scores = q.matmul(k.transpose(1, 2)).scale(scale)
  if causal {
    for i in 0..<b {
      for r in 0..<tq {
        for c in 0..<tk {
          if c > r {
            scores.data[(i * tq + r) * tk + c] = -1.0e300
          }
        }
      }
    }
  }
  scores.softmax().matmul(v)
}

///|
/// 沿序列维（dim=1）拼接两个 [B,T,d] 张量，用于 KV cache。
pub fn cat_seq(a : Tensor, b : Tensor) -> Tensor raise TensorError {
  guard a.shape.length() == 3 && b.shape.length() == 3 else {
    raise TensorError::ShapeMismatch("cat_seq expects 3D inputs")
  }
  guard a.shape[0] == b.shape[0] && a.shape[2] == b.shape[2] else {
    raise TensorError::ShapeMismatch("cat_seq shapes mismatch")
  }
  let batch = a.shape[0]
  let t1 = a.shape[1]
  let t2 = b.shape[1]
  let d = a.shape[2]
  let data = Array::make(batch * (t1 + t2) * d, 0.0)
  for i in 0..<batch {
    let base_a = i * t1 * d
    let base_b = i * t2 * d
    let base_out = i * (t1 + t2) * d
    for j in 0..<(t1 * d) {
      data[base_out + j] = a.data[base_a + j]
    }
    for j in 0..<(t2 * d) {
      data[base_out + t1 * d + j] = b.data[base_b + j]
    }
  }
  { shape: [batch, t1 + t2, d], data, }
}

///|
/// 2D 张量沿 axis（0 或 1）拼接。
pub fn concat_2d(
  a : Tensor,
  b : Tensor,
  axis : Int,
) -> Tensor raise TensorError {
  guard a.shape.length() == 2 && b.shape.length() == 2 else {
    raise TensorError::ShapeMismatch("concat_2d expects 2D inputs")
  }
  guard axis == 0 || axis == 1 else {
    raise TensorError::ShapeMismatch("concat_2d axis must be 0 or 1")
  }
  let other_dim = 1 - axis
  guard a.shape[other_dim] == b.shape[other_dim] else {
    raise TensorError::ShapeMismatch("concat dims mismatch")
  }
  let rows_a = a.shape[0]
  let cols_a = a.shape[1]
  let data : Array[Double] = []
  if axis == 0 {
    for x in a.data {
      let _ = data.push(x)
    }
    for x in b.data {
      let _ = data.push(x)
    }
    { shape: [rows_a + b.shape[0], cols_a], data, }
  } else {
    for i in 0..<rows_a {
      for j in 0..<cols_a {
        let _ = data.push(a.data[i * cols_a + j])
      }
      for j in 0..<b.shape[1] {
        let _ = data.push(b.data[i * b.shape[1] + j])
      }
    }
    { shape: [rows_a, cols_a + b.shape[1]], data, }
  }
}

///|
/// 多头注意力：q/k/v 形状 [B,T,H*D]，按 num_heads 拆分后逐头计算。
pub fn multi_head_attention(
  q : Tensor,
  k : Tensor,
  v : Tensor,
  num_heads : Int,
  causal : Bool,
) -> Tensor raise TensorError {
  guard q.shape[2] % num_heads == 0 else {
    raise TensorError::ShapeMismatch("head dim not divisible")
  }
  let b = q.shape[0]
  let t = q.shape[1]
  let hd = q.shape[2]
  let d = hd / num_heads
  let q = q
    .reshape([b, t, num_heads, d])
    .transpose(1, 2)
    .reshape([b * num_heads, t, d])
  let k = k
    .reshape([b, k.shape[1], num_heads, d])
    .transpose(1, 2)
    .reshape([b * num_heads, k.shape[1], d])
  let v = v
    .reshape([b, v.shape[1], num_heads, d])
    .transpose(1, 2)
    .reshape([b * num_heads, v.shape[1], d])
  attention(q, k, v, causal)
  .reshape([b, num_heads, t, d])
  .transpose(1, 2)
  .reshape([b, t, hd])
}
