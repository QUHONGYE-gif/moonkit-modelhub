///|
/// moonkit/nn 演示：matmul / gelu / softmax / attention。
/// 运行：moon run examples/tensor_demo --target native
fn main {
  let a = @nn.Tensor::from_array_2d([[1.0, 2.0], [3.0, 4.0]])
  let b = @nn.Tensor::from_array_2d([[5.0, 6.0], [7.0, 8.0]])
  let c = a.matmul(b) catch { e => abort("matmul failed: \{e}") }
  println("matmul shape: \{@debug.to_string(c.shape)}")
  println("matmul data:  \{@debug.to_string(c.data)}")

  let g = c.gelu()
  println("gelu:         \{@debug.to_string(g.data)}")

  let s = c.softmax() catch { e => abort("softmax failed: \{e}") }
  println("softmax:      \{@debug.to_string(s.data)}")

  // 单头注意力：[B=1, T=2, d=2]
  let q = @nn.Tensor::from_array_2d([[1.0, 0.0], [0.0, 1.0]]).reshape([1, 2, 2]) catch {
    e => abort("reshape: \{e}")
  }
  let k = q
  let v = @nn.Tensor::from_array_2d([[1.0, 2.0], [3.0, 4.0]]).reshape([1, 2, 2]) catch {
    e => abort("reshape: \{e}")
  }
  let attn = @nn.attention(q, k, v, true) catch {
    e => abort("attention failed: \{e}")
  }
  println("attention:    \{@debug.to_string(attn.data)}")

  let r = @nn.Tensor::randn([4], 42UL)
  println("randn(seed=42): \{@debug.to_string(r.data)}")
}
