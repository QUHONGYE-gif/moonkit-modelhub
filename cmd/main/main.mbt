///|
/// modelhub CLI：下载 HuggingFace 仓库中的单个文件。
/// Run with `moon run cmd/main --target native -- <repo> <file>`.
async fn main {
  let matches = @argparse.Command(
    "modelhub",
    about="Download a single file from a HuggingFace repo",
    options=[
      OptionArg(
        "revision",
        long="revision",
        about="git revision (default: main)",
      ),
      OptionArg(
        "cache-dir",
        long="cache-dir",
        about="cache directory (default: HF_HUB_CACHE or ~/.cache/huggingface/hub)",
      ),
      OptionArg(
        "endpoint",
        long="endpoint",
        about="hub endpoint (default: HF_ENDPOINT or https://huggingface.co)",
      ),
      OptionArg(
        "subfolder",
        long="subfolder",
        about="subfolder of the file within the repo",
      ),
    ],
    positionals=[
      PositionArg(
        "repo",
        about="repo id, e.g. openai-community/gpt2",
        num_args=@argparse.ValueRange::single(),
      ),
      PositionArg(
        "file",
        about="filename within the repo",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  ).parse()
  guard matches.values is { "repo": [repo], "file": [file], .. } else {
    fail("usage: modelhub <repo> <file> [--revision REV] [--cache-dir DIR]")
  }
  let endpoint = match matches.values {
    { "endpoint": [e], .. } => e
    _ => @modelhub.default_endpoint()
  }
  let cache = match matches.values {
    { "cache-dir": [c], .. } => c
    _ => @modelhub.default_cache_dir()
  }
  let revision = match matches.values {
    { "revision": [r], .. } => r
    _ => "main"
  }
  let subfolder = match matches.values {
    { "subfolder": [s], .. } => s
    _ => ""
  }
  let config = @modelhub.HubConfig::with_subfolder(
    @modelhub.HubConfig::with_revision(
      @modelhub.HubConfig::new(endpoint, cache),
      revision,
    ),
    subfolder,
  )
  let path = @modelhub.hf_hub_download(repo, file, config) catch {
    e => {
      println("error: \{e}")
      return
    }
  }
  println(path)
}
