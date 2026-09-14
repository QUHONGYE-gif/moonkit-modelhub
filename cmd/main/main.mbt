///|
/// modelhub CLI：HuggingFace Hub 客户端。
/// Run with `moon run cmd/main --target native -- <subcommand> ...`.
async fn main {
  let matches = @argparse.Command(
    "modelhub",
    about="HuggingFace Hub client in MoonBit",
    subcommands=[
      @argparse.Command(
        "download",
        about="Download a single file from a repo",
        options=[
          OptionArg(
            "revision",
            long="revision",
            about="git revision (default: main)",
          ),
          OptionArg("cache-dir", long="cache-dir", about="cache directory"),
          OptionArg("endpoint", long="endpoint", about="hub endpoint"),
          OptionArg(
            "subfolder",
            long="subfolder",
            about="subfolder of the file",
          ),
        ],
        positionals=[
          PositionArg(
            "repo",
            about="repo id",
            num_args=@argparse.ValueRange::single(),
          ),
          PositionArg(
            "file",
            about="filename within the repo",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
      @argparse.Command(
        "snapshot",
        about="Download a full repo snapshot",
        options=[
          OptionArg(
            "revision",
            long="revision",
            about="git revision (default: main)",
          ),
          OptionArg("cache-dir", long="cache-dir", about="cache directory"),
          OptionArg("endpoint", long="endpoint", about="hub endpoint"),
          OptionArg(
            "include",
            long="include",
            about="only download files matching GLOB (repeatable)",
          ),
          OptionArg(
            "exclude",
            long="exclude",
            about="skip files matching GLOB (repeatable)",
          ),
        ],
        positionals=[
          PositionArg(
            "repo",
            about="repo id",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
      @argparse.Command(
        "info",
        about="Show repo metadata",
        options=[
          OptionArg("endpoint", long="endpoint", about="hub endpoint"),
          OptionArg("cache-dir", long="cache-dir", about="cache directory"),
        ],
        positionals=[
          PositionArg(
            "repo",
            about="repo id",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
    ],
  ).parse()
  let config = @modelhub.default_config()
  match matches.subcommand {
    Some(("download", m)) => run_download(m, config)
    Some(("snapshot", m)) => run_snapshot(m, config)
    Some(("info", m)) => run_info(m, config)
    _ =>
      println(
        "usage: modelhub <download|snapshot|info> ... (try `modelhub help`)",
      )
  }
}

///|
fn option_str(values : Map[String, Array[String]], key : String) -> String? {
  match values.get(key) {
    Some([v]) => Some(v)
    _ => None
  }
}

///|
fn config_with(
  values : Map[String, Array[String]],
  config : @modelhub.HubConfig,
) -> @modelhub.HubConfig {
  let mut c = config
  match option_str(values, "endpoint") {
    Some(e) => c = c.with_endpoint(e)
    None => ()
  }
  match option_str(values, "cache-dir") {
    Some(d) => c = c.with_cache_dir(d)
    None => ()
  }
  match option_str(values, "revision") {
    Some(r) => c = c.with_revision(r)
    None => ()
  }
  c
}

///|
async fn run_download(
  m : @argparse.Matches,
  config : @modelhub.HubConfig,
) -> Unit {
  guard m.values is { "repo": [repo], "file": [file], .. } else {
    fail("usage: modelhub download <repo> <file>")
  }
  let c = config_with(m.values, config)
  let path = @modelhub.hf_hub_download(repo, file, c) catch {
    e => {
      println("error: \{e}")
      return
    }
  }
  println(path)
}

///|
async fn run_snapshot(
  m : @argparse.Matches,
  config : @modelhub.HubConfig,
) -> Unit {
  guard m.values is { "repo": [repo], .. } else {
    fail("usage: modelhub snapshot <repo>")
  }
  let c = config_with(m.values, config)
  let allow = m.values.get("include")
  let ignore = m.values.get("exclude")
  let snap = @modelhub.snapshot_download(repo, c, allow, ignore) catch {
    e => {
      println("error: \{e}")
      return
    }
  }
  println(snap)
}

///|
async fn run_info(m : @argparse.Matches, config : @modelhub.HubConfig) -> Unit {
  guard m.values is { "repo": [repo], .. } else {
    fail("usage: modelhub info <repo>")
  }
  let c = config_with(m.values, config)
  let info = @modelhub.model_info(repo, c) catch {
    e => {
      println("error: \{e}")
      return
    }
  }
  println(@debug.to_string(info))
}
