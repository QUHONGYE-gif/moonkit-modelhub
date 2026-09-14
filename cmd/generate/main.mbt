///|
/// transformers CLI：modelhub 拉模型 → tokenizers-moonbit 分词 → GPT-2 生成。
async fn main {
  let matches = @argparse.Command(
    "generate",
    about="Pull a GPT-2 model via modelhub and generate text",
    options=[
      OptionArg(
        "endpoint",
        long="endpoint",
        about="hub endpoint (default: HF_ENDPOINT or https://huggingface.co)",
      ),
      OptionArg("cache-dir", long="cache-dir", about="cache directory"),
      OptionArg("max-new", long="max-new", about="max new tokens (default: 20)"),
      OptionArg(
        "temperature",
        long="temperature",
        about="sampling temperature, 0 = greedy (default: 0)",
      ),
      OptionArg("prompt", long="prompt", about="prompt text (default: a)"),
    ],
    positionals=[
      PositionArg(
        "repo",
        about="repo id (default: hf-internal-testing/tiny-random-gpt2)",
        num_args=@argparse.ValueRange(lower=0, upper=1),
      ),
    ],
  ).parse()
  let repo = match matches.values.get("repo") {
    Some([r]) => r
    _ => "hf-internal-testing/tiny-random-gpt2"
  }
  let prompt = match matches.values.get("prompt") {
    Some([p]) => p
    _ => "a"
  }
  let max_new = match matches.values.get("max-new") {
    Some([n]) => @string.parse_int(n) catch { _ => 20 }
    _ => 20
  }
  let temperature = match matches.values.get("temperature") {
    Some([t]) => @string.parse_double(t) catch { _ => 0.0 }
    _ => 0.0
  }
  let config = @modelhub.default_config()
  let config = match matches.values.get("endpoint") {
    Some([e]) => config.with_endpoint(e)
    _ => config
  }
  let config = match matches.values.get("cache-dir") {
    Some([c]) => config.with_cache_dir(c)
    _ => config
  }
  let snap = @modelhub.snapshot_download(repo, config, None, None) catch {
    e => abort("snapshot failed: \{e}")
  }
  let cfg_json = @json.parse(@fs.read_file("\{snap}/config.json").text()) catch {
    _ => abort("config.json parse failed")
  }
  let cfg = @transformers.parse_config(cfg_json) catch {
    e => abort("config failed: \{e}")
  }
  let weights = @transformers.parse_safetensors(
    @fs.read_file("\{snap}/model.safetensors").binary(),
  ) catch {
    e => abort("weights failed: \{e}")
  }
  let model = @transformers.Gpt2Model::load(cfg, weights) catch {
    e => abort("model load failed: \{e}")
  }
  let tok = @tokenizer.Tokenizer::from_file("\{snap}/tokenizer.json") catch {
    _ => abort("tokenizer load failed")
  }
  let enc = tok.encode(prompt) catch { _ => abort("encode failed") }
  // demo 钳制：小模型 vocab 小于完整 tokenizer 词表时，把 id 收进范围内。
  let ids = enc.ids.map(fn(i) { i % cfg.vocab_size })
  let gen = @transformers.Generator::new(model)
  let out = gen.generate(ids, max_new, temperature) catch {
    e => abort("generate failed: \{e}")
  }
  let text = tok.decode(out, skip_special_tokens=true) catch {
    _ => abort("decode failed")
  }
  println("repo: \{repo}")
  println("prompt: \{prompt}")
  println("tokens: \{out}")
  println("output: \{text}")
}
