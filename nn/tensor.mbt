// moonkit/nn：Double 张量（f64、行主序），推理内核的地基。

///|
pub(all) suberror TensorError {
  ShapeMismatch(String)
} derive(@debug.Debug)

///|
pub impl Show for TensorError with fn output(self, logger) {
  match self {
    ShapeMismatch(msg) => logger.write_string(msg)
  }
}

///|
pub struct Tensor {
  /// 形状（行主序）。
  shape : Array[Int]
  /// 底层数据。
  data : Array[Double]
} derive(@debug.Debug)

///|
fn numel_of(shape : Array[Int]) -> Int {
  let mut n = 1
  for d in shape {
    n *= d
  }
  n
}

///|
/// 构造张量；数据长度必须等于各维乘积。
pub fn Tensor::new(
  shape : Array[Int],
  data : Array[Double],
) -> Tensor raise TensorError {
  guard data.length() == numel_of(shape) else {
    raise TensorError::ShapeMismatch(
      "data length \{data.length()} != numel \{numel_of(shape)}",
    )
  }
  { shape, data, }
}

///|
pub fn Tensor::zeros(shape : Array[Int]) -> Tensor {
  { shape, data: Array::make(numel_of(shape), 0.0), }
}

///|
/// 从二维数组构造（测试/示例便利方法）。
pub fn Tensor::from_array_2d(a : Array[Array[Double]]) -> Tensor {
  let rows = a.length()
  let cols = if rows > 0 { a[0].length() } else { 0 }
  let data : Array[Double] = []
  for row in a {
    for x in row {
      let _ = data.push(x)
    }
  }
  { shape: [rows, cols], data, }
}

///|
pub fn Tensor::numel(self : Tensor) -> Int {
  self.data.length()
}

///|
/// 变形；元素总数必须一致。
pub fn Tensor::reshape(
  self : Tensor,
  shape : Array[Int],
) -> Tensor raise TensorError {
  guard numel_of(shape) == self.data.length() else {
    raise TensorError::ShapeMismatch(
      "reshape numel mismatch: \{numel_of(shape)} vs \{self.data.length()}",
    )
  }
  { shape, data: self.data, }
}

///|
fn offset(shape : Array[Int], idx : Array[Int]) -> Int {
  let mut o = 0
  for i in 0..<idx.length() {
    o = o * shape[i] + idx[i]
  }
  o
}

///|
/// 交换两个维度。
pub fn Tensor::transpose(self : Tensor, dim0 : Int, dim1 : Int) -> Tensor {
  let rank = self.shape.length()
  let new_shape = self.shape.copy()
  new_shape[dim0] = self.shape[dim1]
  new_shape[dim1] = self.shape[dim0]
  let new_data = Array::make(self.data.length(), 0.0)
  let idx = Array::make(rank, 0)
  for flat in 0..<self.data.length() {
    let mut t = flat
    for i = rank - 1; i >= 0; i = i - 1 {
      idx[i] = t % self.shape[i]
      t /= self.shape[i]
    }
    let tmp = idx[dim0]
    idx[dim0] = idx[dim1]
    idx[dim1] = tmp
    new_data[offset(new_shape, idx)] = self.data[flat]
  }
  { shape: new_shape, data: new_data, }
}

///|
fn zip_impl(
  a : Tensor,
  b : Tensor,
  f : (Double, Double) -> Double,
) -> Tensor raise TensorError {
  guard a.shape == b.shape else {
    raise TensorError::ShapeMismatch("elementwise shapes differ")
  }
  let data = Array::make(a.data.length(), 0.0)
  for i in 0..<a.data.length() {
    data[i] = f(a.data[i], b.data[i])
  }
  { shape: a.shape, data, }
}

///|
pub fn Tensor::add(self : Tensor, other : Tensor) -> Tensor raise TensorError {
  zip_impl(self, other, fn(x, y) { x + y })
}

///|
pub fn Tensor::sub(self : Tensor, other : Tensor) -> Tensor raise TensorError {
  zip_impl(self, other, fn(x, y) { x - y })
}

///|
pub fn Tensor::mul(self : Tensor, other : Tensor) -> Tensor raise TensorError {
  zip_impl(self, other, fn(x, y) { x * y })
}

///|
pub fn Tensor::scale(self : Tensor, s : Double) -> Tensor {
  { shape: self.shape, data: self.data.map(fn(x) { x * s }), }
}

///|
/// 沿最后一维广播加 bias（形状 [cols]）。
pub fn Tensor::add_bias(
  self : Tensor,
  bias : Tensor,
) -> Tensor raise TensorError {
  guard bias.shape.length() == 1 else {
    raise TensorError::ShapeMismatch("bias must be 1D")
  }
  let cols = self.shape[self.shape.length() - 1]
  guard bias.shape[0] == cols else {
    raise TensorError::ShapeMismatch("bias length \{bias.shape[0]} != \{cols}")
  }
  let data = self.data.mapi(fn(i, x) { x + bias.data[i % cols] })
  { shape: self.shape, data, }
}

///|
/// xorshift64* 一步。
fn xorshift_next(state : UInt64) -> UInt64 {
  let mut x = state
  x = x ^ (x >> 12)
  x = x ^ (x << 25)
  x = x ^ (x >> 27)
  x
}

///|
/// 固定种子的标准正态随机张量（xorshift + Box-Muller）。
pub fn Tensor::randn(shape : Array[Int], seed : UInt64) -> Tensor {
  let n = numel_of(shape)
  let mut state = if seed == 0 { 0x9E3779B97F4A7C15UL } else { seed }
  let data : Array[Double] = []
  while data.length() < n {
    state = xorshift_next(state)
    let u1 = (state * 0x2545F4914F6CDD1DUL).to_double() / 1.8446744073709552e19
    state = xorshift_next(state)
    let u2 = (state * 0x2545F4914F6CDD1DUL).to_double() / 1.8446744073709552e19
    let u1 = if u1 < 1.0e-12 { 1.0e-12 } else { u1 }
    let r = @math.pow(-2.0 * @math.ln(u1), 0.5)
    let theta = 2.0 * 3.141592653589793 * u2
    let _ = data.push(r * @math.cos(theta))
    if data.length() < n {
      let _ = data.push(r * @math.sin(theta))
    }
  }
  { shape, data, }
}
