// moonkit/nn：矩阵乘法（朴素实现，正确性优先）。

///|
fn matmul_2d(a : Tensor, b : Tensor) -> Tensor raise TensorError {
  let m = a.shape[0]
  let k = a.shape[1]
  let k2 = b.shape[0]
  let n = b.shape[1]
  guard k == k2 else {
    raise TensorError::ShapeMismatch("inner dims \{k} != \{k2}")
  }
  let data = Array::make(m * n, 0.0)
  for i in 0..<m {
    for j in 0..<n {
      let mut s = 0.0
      for p in 0..<k {
        s = s + a.data[i * k + p] * b.data[p * n + j]
      }
      data[i * n + j] = s
    }
  }
  { shape: [m, n], data, }
}

///|
/// 矩阵乘法：支持 2D 与批处理 3D（batch matmul）。
pub fn Tensor::matmul(
  self : Tensor,
  other : Tensor,
) -> Tensor raise TensorError {
  if self.shape.length() == 2 && other.shape.length() == 2 {
    matmul_2d(self, other)
  } else if self.shape.length() == 3 && other.shape.length() == 2 {
    let b = self.shape[0]
    let m = self.shape[1]
    let k = self.shape[2]
    let k2 = other.shape[0]
    let n = other.shape[1]
    guard k == k2 else {
      raise TensorError::ShapeMismatch("inner dims \{k} != \{k2}")
    }
    let data = Array::make(b * m * n, 0.0)
    for i in 0..<b {
      for r in 0..<m {
        for c in 0..<n {
          let mut s = 0.0
          for p in 0..<k {
            s = s + self.data[(i * m + r) * k + p] * other.data[p * n + c]
          }
          data[(i * m + r) * n + c] = s
        }
      }
    }
    { shape: [b, m, n], data, }
  } else if self.shape.length() == 3 && other.shape.length() == 3 {
    guard self.shape[0] == other.shape[0] else {
      raise TensorError::ShapeMismatch("batch size mismatch")
    }
    let b = self.shape[0]
    let m = self.shape[1]
    let k = self.shape[2]
    let k2 = other.shape[1]
    let n = other.shape[2]
    guard k == k2 else {
      raise TensorError::ShapeMismatch("inner dims \{k} != \{k2}")
    }
    let data = Array::make(b * m * n, 0.0)
    for i in 0..<b {
      for r in 0..<m {
        for c in 0..<n {
          let mut s = 0.0
          for p in 0..<k {
            s = s +
              self.data[(i * m + r) * k + p] * other.data[(i * k + p) * n + c]
          }
          data[(i * m + r) * n + c] = s
        }
      }
    }
    { shape: [b, m, n], data, }
  } else {
    raise TensorError::ShapeMismatch("matmul supports 2D or 3D")
  }
}
