///|
/// modelhub 演示：从 Hub（或本地 mock）下载单个文件到 HF 兼容缓存。
/// 运行：HF_ENDPOINT=http://127.0.0.1:8765 moon run examples/hub_demo --target native
async fn main {
  let endpoint = @env.get_env_var("HF_ENDPOINT").unwrap_or(
    "https://hf-mirror.com",
  )
  let cache = @env.get_env_var("HF_HUB_CACHE").unwrap_or(
    "/tmp/modelhub-hub-demo",
  )
  let config = @modelhub.HubConfig::new(endpoint, cache)
  println("endpoint: \{endpoint}")
  let path = @modelhub.hf_hub_download("gpt2", "config.json", config) catch {
    e => abort("download failed: \{e}")
  }
  println("downloaded: \{path}")
  let text = @fs.read_file(path).text() catch { _ => abort("read failed") }
  println("preview: \{text[:60]}")
}
