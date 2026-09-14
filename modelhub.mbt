// modelhub：MoonBit 的 HuggingFace Hub 客户端。

///|
pub(all) suberror HubError {
  RevisionNotFound(String)
  EntryNotFound(String)
  GatedRepo(String)
  Offline(String)
  BadStatus(Int, String)
  Parse(String)
  Io(String)
} derive(Eq, @debug.Debug)

///|
pub impl Show for HubError with fn output(self, logger) {
  match self {
    RevisionNotFound(url) => logger <+ "revision not found: \{url}"
    EntryNotFound(url) => logger <+ "entry not found: \{url}"
    GatedRepo(url) => logger <+ "gated repo, token required: \{url}"
    Offline(what) => logger <+ "offline mode: \{what}"
    BadStatus(code, url) => logger <+ "bad status \{code} from \{url}"
    Parse(msg) => logger.write_string(msg)
    Io(msg) => logger.write_string(msg)
  }
}

///|
pub struct HubConfig {
  endpoint : String
  cache_dir : String
  revision : String
  subfolder : String
  token : String?
  offline : Bool
}

///|
pub fn HubConfig::new(endpoint : String, cache_dir : String) -> HubConfig {
  {
    endpoint,
    cache_dir,
    revision: "main",
    subfolder: "",
    token: None,
    offline: false,
  }
}

///|
pub fn HubConfig::with_revision(
  self : HubConfig,
  revision : String,
) -> HubConfig {
  { ..self, revision, }
}

///|
pub fn HubConfig::with_subfolder(
  self : HubConfig,
  subfolder : String,
) -> HubConfig {
  { ..self, subfolder, }
}

///|
pub fn HubConfig::with_token(self : HubConfig, token : String) -> HubConfig {
  { ..self, token: Some(token), }
}

///|
pub fn HubConfig::with_offline(self : HubConfig, offline : Bool) -> HubConfig {
  { ..self, offline, }
}

///|
pub fn HubConfig::with_endpoint(
  self : HubConfig,
  endpoint : String,
) -> HubConfig {
  { ..self, endpoint, }
}

///|
pub fn HubConfig::with_cache_dir(
  self : HubConfig,
  cache_dir : String,
) -> HubConfig {
  { ..self, cache_dir, }
}

///|
/// 默认端点：HF_ENDPOINT 环境变量，否则官方地址。
pub fn default_endpoint() -> String {
  @env.get_env_var("HF_ENDPOINT").unwrap_or("https://huggingface.co")
}

///|
/// 默认缓存根目录：HF_HUB_CACHE，否则 ~/.cache/huggingface/hub。
pub fn default_cache_dir() -> String {
  match @env.get_env_var("HF_HUB_CACHE") {
    Some(p) => p
    None =>
      match @env.get_env_var("HOME") {
        Some(h) => "\{h}/.cache/huggingface/hub"
        None => "/tmp/huggingface/hub"
      }
  }
}

///|
/// 离线模式默认值：HF_HUB_OFFLINE ∈ {1,true,TRUE,yes}。
pub fn default_offline() -> Bool {
  match @env.get_env_var("HF_HUB_OFFLINE") {
    Some(v) => v == "1" || v == "true" || v == "TRUE" || v == "yes"
    None => false
  }
}

///|
/// 认证 token 默认值：HF_TOKEN → HUGGING_FACE_HUB_TOKEN → token 文件。
pub async fn load_default_token() -> String? {
  match @env.get_env_var("HF_TOKEN") {
    Some(t) => Some(t)
    None =>
      match @env.get_env_var("HUGGING_FACE_HUB_TOKEN") {
        Some(t) => Some(t)
        None => read_token_file()
      }
  }
}

///|
async fn read_token_file() -> String? {
  let home = match @env.get_env_var("HOME") {
    Some(h) => h
    None => return None
  }
  match read_refs_file("\{home}/.cache/huggingface/token") {
    Some(t) => {
      let trimmed = t.trim().to_owned()
      if trimmed.is_empty() {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
/// 从环境变量组装默认配置。
pub async fn default_config() -> HubConfig {
  let base = HubConfig::new(default_endpoint(), default_cache_dir()).with_offline(
    default_offline(),
  )
  match load_default_token() {
    Some(t) => base.with_token(t)
    None => base
  }
}

///|
fn auth_headers(token : String?) -> @http.Headers {
  match token {
    None => Map([])
    Some(t) => { "Authorization": "Bearer \{t}" }
  }
}

///|
fn strip_quotes(s : String) -> String {
  let s2 = if s.has_prefix("W/") { s[2:].to_owned() } else { s }
  if s2.length() >= 2 && s2.has_prefix("\"") && s2.has_suffix("\"") {
    s2[1:s2.length() - 1].to_owned()
  } else {
    s2
  }
}

///|
/// 解析 revision 为 commit sha：优先读本地 refs 文件（零网络），
/// 否则请求远端 API 并写回 refs。
pub async fn resolve_sha(
  endpoint : String,
  repo_id : String,
  revision : String,
  cache_dir : String,
  token : String?,
  offline : Bool,
) -> String raise HubError {
  let refs = refs_path(cache_dir, repo_id, revision)
  match read_refs_file(refs) {
    Some(sha) => sha
    None => {
      guard !offline else {
        raise HubError::Offline("revision not cached: \{revision}")
      }
      let (sha, _siblings) = fetch_revision_info(
        endpoint, repo_id, revision, token,
      )
      ensure_dir(dirname(refs))
      write_file_checked(refs, sha)
      sha
    }
  }
}

///|
/// 下载 url 到 blobs 目录：探测 etag，流式写入 blobs/<etag>.incomplete，
/// 支持断点续传（Range），完成后重命名为 blobs/<etag>，返回 etag。
pub async fn download_resumable(
  url : String,
  token : String?,
  cache_root : String,
  repo_id : String,
) -> String raise HubError {
  let blobs = blob_dir(cache_root, repo_id)
  let (code, linked_etag, client) = get_stream_follow(
    url,
    auth_headers(token),
    10,
  )
  if code == 401 || code == 403 {
    client.close()
    raise HubError::GatedRepo(url)
  }
  if code == 404 {
    client.close()
    raise HubError::EntryNotFound(url)
  }
  guard code == 200 else {
    client.close()
    raise HubError::BadStatus(code, url)
  }
  let etag = match linked_etag {
    Some(e) => strip_quotes(e)
    None => {
      client.close()
      raise HubError::Parse("missing `etag` header from \{url}")
    }
  }
  let dest = "\{blobs}/\{etag}"
  if path_exists(dest) {
    client.close()
    return etag
  }
  let incomplete = dest + ".incomplete"
  let offset = partial_size(incomplete)
  if offset > 0 {
    client.close()
    let headers2 : @http.Headers = match token {
      None => { "Range": "bytes=\{offset}-" }
      Some(t) => { "Authorization": "Bearer \{t}", "Range": "bytes=\{offset}-" }
    }
    let (code2, _linked2, client2) = get_stream_follow(url, headers2, 10)
    guard code2 == 206 else {
      client2.close()
      raise HubError::BadStatus(code2, url)
    }
    copy_stream(client2, incomplete, offset)
    rename_checked(incomplete, dest)
  } else {
    copy_stream(client, incomplete, 0)
    rename_checked(incomplete, dest)
  }
  let repo_name = repo_id.replace_all(old="/", new="--")
  let lock = "\{cache_root}/.locks/models--\{repo_name}/\{etag}.lock"
  ensure_dir(dirname(lock))
  write_file_checked(lock, "")
  etag
}

///|
/// 把 client 的剩余响应体写入 path；offset > 0 时以追加模式续写。
/// 中断时保留已写入的部分并抛 Io。
pub async fn copy_stream(
  client : @http.Client,
  path : String,
  offset : Int,
) -> Unit raise HubError {
  let resuming = offset > 0
  let create_mode = if resuming {
    @fs.CreateMode::OpenExisting
  } else {
    @fs.CreateMode::CreateOrTruncate
  }
  let file = @fs.open(
    path,
    mode=@fs.Mode::WriteOnly,
    append=resuming,
    create_mode~,
  ) catch {
    _ => raise HubError::Io("open failed: \{path}")
  }
  try {
    while client.read_some() is Some(chunk) {
      file.write(chunk)
    }
  } catch {
    _ => {
      file.close()
      raise HubError::Io("download interrupted: \{path}")
    }
  }
  file.close()
}

///|
/// 下载 repo 中的单个文件到 HF 兼容缓存，返回快照目录中的本地文件路径。
/// 缓存命中时不做任何网络请求。
pub async fn hf_hub_download(
  repo_id : String,
  filename : String,
  config : HubConfig,
) -> String raise HubError {
  ensure_cache_tag(config.cache_dir)
  let sha = resolve_sha(
    config.endpoint,
    repo_id,
    config.revision,
    config.cache_dir,
    config.token,
    config.offline,
  )
  let rel_file = if config.subfolder.is_empty() {
    filename
  } else {
    config.subfolder + "/" + filename
  }
  let snap_file = "\{snapshot_dir(config.cache_dir, repo_id, sha)}/\{rel_file}"
  if path_exists(snap_file) {
    return snap_file
  }
  guard !config.offline else {
    raise HubError::Offline("\{repo_id}/\{filename} not cached")
  }
  let url = "\{config.endpoint}/\{repo_id}/resolve/\{config.revision}/\{filename}"
  let blobs = blob_dir(config.cache_dir, repo_id)
  ensure_dir(blobs)
  let etag = download_resumable(url, config.token, config.cache_dir, repo_id)
  let snap_dir = dirname(snap_file)
  ensure_dir(snap_dir)
  symlink_checked("../../blobs/\{etag}", snap_file)
  snap_file
}
