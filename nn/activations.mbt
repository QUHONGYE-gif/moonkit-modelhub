// moonkit/nn：激活与归一化。

///|
pub fn Tensor::relu(self : Tensor) -> Tensor {
  {
    shape: self.shape,
    data: self.data.map(fn(x) { if x > 0.0 { x } else { 0.0 } }),
  }
}

///|
pub fn Tensor::sigmoid(self : Tensor) -> Tensor {
  {
    shape: self.shape,
    data: self.data.map(fn(x) { 1.0 / (1.0 + @math.exp(-x)) }),
  }
}

///|
pub fn Tensor::tanh(self : Tensor) -> Tensor {
  { shape: self.shape, data: self.data.map(fn(x) { @math.tanh(x) }), }
}

///|
/// GPT-2 同款 GELU tanh 近似。
pub fn Tensor::gelu(self : Tensor) -> Tensor {
  let c = 0.7978845608028654
  let data = self.data.map(fn(x) {
    let t = x * x * x * 0.044715
    0.5 * x * (1.0 + @math.tanh(c * (x + t)))
  })
  { shape: self.shape, data, }
}

///|
/// 数值稳定 softmax，沿最后一维。
pub fn Tensor::softmax(self : Tensor) -> Tensor raise TensorError {
  self.softmax_axis(self.shape.length() - 1)
}

///|
/// 数值稳定 softmax，沿指定维。
pub fn Tensor::softmax_axis(
  self : Tensor,
  axis : Int,
) -> Tensor raise TensorError {
  guard self.shape.length() >= 1 else {
    raise TensorError::ShapeMismatch("softmax expects rank >= 1")
  }
  let ax = if axis < 0 { self.shape.length() + axis } else { axis }
  guard ax >= 0 && ax < self.shape.length() else {
    raise TensorError::ShapeMismatch("softmax axis out of range")
  }
  let axis_size = self.shape[ax]
  let mut inner = 1
  for i = ax + 1; i < self.shape.length(); i = i + 1 {
    inner = inner * self.shape[i]
  }
  let outer = self.data.length() / (axis_size * inner)
  let data = Array::make(self.data.length(), 0.0)
  for o in 0..<outer {
    for j in 0..<inner {
      let base = o * axis_size * inner + j
      let mut mx = self.data[base]
      for k in 1..<axis_size {
        let v = self.data[base + k * inner]
        if v > mx {
          mx = v
        }
      }
      let mut sum = 0.0
      for k in 0..<axis_size {
        let e = @math.exp(self.data[base + k * inner] - mx)
        data[base + k * inner] = e
        sum = sum + e
      }
      for k in 0..<axis_size {
        data[base + k * inner] = data[base + k * inner] / sum
      }
    }
  }
  { shape: self.shape, data, }
}

///|
/// LayerNorm 沿最后一维；weight/bias 可选（形状 [cols]）。
pub fn Tensor::layer_norm(
  self : Tensor,
  weight : Tensor?,
  bias : Tensor?,
  eps : Double,
) -> Tensor raise TensorError {
  norm_impl(self, weight, bias, eps, false)
}

///|
/// RMSNorm 沿最后一维；weight 可选（形状 [cols]）。
pub fn Tensor::rms_norm(
  self : Tensor,
  weight : Tensor?,
  eps : Double,
) -> Tensor raise TensorError {
  norm_impl(self, weight, None, eps, true)
}

///|
fn norm_impl(
  x : Tensor,
  weight : Tensor?,
  bias : Tensor?,
  eps : Double,
  rms : Bool,
) -> Tensor raise TensorError {
  guard x.shape.length() >= 1 else {
    raise TensorError::ShapeMismatch("norm expects rank >= 1")
  }
  let cols = x.shape[x.shape.length() - 1]
  let rows = x.data.length() / cols
  let data = Array::make(x.data.length(), 0.0)
  for r in 0..<rows {
    let base = r * cols
    if rms {
      let mut ms = 0.0
      for c in 0..<cols {
        ms = ms + x.data[base + c] * x.data[base + c]
      }
      let inv = 1.0 / @math.pow(ms / cols.to_double() + eps, 0.5)
      for c in 0..<cols {
        let mut v = x.data[base + c] * inv
        match weight {
          Some(w) => v = v * w.data[c]
          None => ()
        }
        data[base + c] = v
      }
    } else {
      let mut mean = 0.0
      for c in 0..<cols {
        mean = mean + x.data[base + c]
      }
      mean = mean / cols.to_double()
      let mut variance = 0.0
      for c in 0..<cols {
        let d = x.data[base + c] - mean
        variance = variance + d * d
      }
      variance = variance / cols.to_double()
      let inv = 1.0 / @math.pow(variance + eps, 0.5)
      for c in 0..<cols {
        let mut v = (x.data[base + c] - mean) * inv
        match weight {
          Some(w) => v = v * w.data[c]
          None => ()
        }
        match bias {
          Some(bb) => v = v + bb.data[c]
          None => ()
        }
        data[base + c] = v
      }
    }
  }
  { shape: x.shape, data, }
}
