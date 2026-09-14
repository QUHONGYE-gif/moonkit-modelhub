// 阶段 3：仓库元信息端点。

///|
pub struct RepoInfo {
  id : String
  sha : String?
  private : Bool
  downloads : Int
  likes : Int
  siblings : Array[String]
} derive(@debug.Debug)

///|
/// 查询模型仓库元信息。
pub async fn model_info(
  repo_id : String,
  config : HubConfig,
) -> RepoInfo raise HubError {
  fetch_repo_info(config.endpoint, "models", repo_id, config.token)
}

///|
/// 查询数据集仓库元信息。
pub async fn dataset_info(
  repo_id : String,
  config : HubConfig,
) -> RepoInfo raise HubError {
  fetch_repo_info(config.endpoint, "datasets", repo_id, config.token)
}

///|
async fn fetch_repo_info(
  endpoint : String,
  kind : String,
  repo_id : String,
  token : String?,
) -> RepoInfo raise HubError {
  let url = "\{endpoint}/api/\{kind}/\{repo_id}"
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
  let id = match obj.get("id") {
    Some(Json::String(s)) => s
    _ => raise HubError::Parse("missing `id` field from \{url}")
  }
  let sha = match obj.get("sha") {
    Some(Json::String(s)) => Some(s)
    _ => None
  }
  let private = match obj.get("private") {
    Some(Json::True) => true
    _ => false
  }
  let downloads = match obj.get("downloads") {
    Some(Json::Number(d, ..)) => d.to_int()
    _ => 0
  }
  let likes = match obj.get("likes") {
    Some(Json::Number(d, ..)) => d.to_int()
    _ => 0
  }
  { id, sha, private, downloads, likes, siblings: parse_siblings(json), }
}
