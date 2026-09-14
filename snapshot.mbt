// 阶段 2：revision 信息（siblings）与快照下载。

///|
/// 请求 revision 信息：commit sha 与文件列表（siblings）。
pub async fn fetch_revision_info(
  endpoint : String,
  repo_id : String,
  revision : String,
  token : String?,
) -> (String, Array[String]) raise HubError {
  let url = "\{endpoint}/api/models/\{repo_id}/revision/\{revision}"
  let (code, _headers, body) = get_follow(url, auth_headers(token), 5)
  if code == 401 || code == 403 {
    raise HubError::GatedRepo(url)
  }
  if code == 404 {
    raise HubError::RevisionNotFound(url)
  }
  guard code == 200 else { raise HubError::BadStatus(code, url) }
  let text = @utf8.decode(body) catch {
    _ => raise HubError::Parse("invalid UTF-8 from \{url}")
  }
  let json = @json.parse(text) catch {
    _ => raise HubError::Parse("invalid JSON from \{url}")
  }
  let obj = match json {
    Json::Object(o) => o
    _ => raise HubError::Parse("expected JSON object from \{url}")
  }
  let sha = match obj.get("sha") {
    Some(Json::String(s)) => s
    _ => raise HubError::Parse("missing or non-string `sha` field from \{url}")
  }
  let files : Array[String] = []
  match obj.get("siblings") {
    Some(Json::Array(items)) =>
      for item in items {
        match item {
          Json::Object(s) =>
            match s.get("rfilename") {
              Some(Json::String(name)) => files.push(name)
              _ => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  (sha, files)
}

///|
fn glob_to_regex(pattern : String) -> String {
  let mut out = "^"
  for ch in pattern {
    if ch == '*' {
      out = out + ".*"
    } else if ch == '?' {
      out = out + "."
    } else {
      if "\\^$.|+()[]{}".contains_char(ch) {
        out = out + "\\"
      }
      out = out + ch.to_string()
    }
  }
  out + "$"
}

///|
/// glob 风格匹配（* / ?），整串匹配。
pub fn matches_glob(filename : String, pattern : String) -> Bool {
  let regex = @string.Regex(glob_to_regex(pattern)) catch { _ => return false }
  regex.execute(filename) is Some(_)
}

///|
fn allowed(
  filename : String,
  allow_patterns : Array[String]?,
  ignore_patterns : Array[String]?,
) -> Bool {
  match ignore_patterns {
    Some(patts) =>
      for p in patts {
        if matches_glob(filename, p) {
          return false
        }
      }
    None => ()
  }
  match allow_patterns {
    Some(patts) if !patts.is_empty() => {
      for p in patts {
        if matches_glob(filename, p) {
          return true
        }
      }
      false
    }
    _ => true
  }
}

///|
/// 下载整个模型快照到 HF 兼容缓存，返回快照目录。
/// 离线模式下暂不支持（需要远端 siblings 列表）。
pub async fn snapshot_download(
  repo_id : String,
  config : HubConfig,
  allow_patterns : Array[String]?,
  ignore_patterns : Array[String]?,
) -> String raise HubError {
  guard !config.offline else {
    raise HubError::Offline(
      "snapshot_download is not available in offline mode",
    )
  }
  let (sha, files) = fetch_revision_info(
    config.endpoint,
    repo_id,
    config.revision,
    config.token,
  )
  let refs = refs_path(config.cache_dir, repo_id, config.revision)
  ensure_dir(dirname(refs))
  write_file_checked(refs, sha)
  for filename in files {
    if allowed(filename, allow_patterns, ignore_patterns) {
      let _ = hf_hub_download(repo_id, filename, config)
    }
  }
  snapshot_dir(config.cache_dir, repo_id, sha)
}
