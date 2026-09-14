// HF 兼容缓存布局的路径构造与文件系统工具。

///|
/// 仓库在缓存中的目录名：models--<repo>，斜杠替换为双连字符。
pub fn repo_cache_dir(cache_root : String, repo_id : String) -> String {
  "\{cache_root}/models--\{repo_id.replace_all(old="/", new="--")}"
}

///|
/// 内容寻址存储目录：blobs/<etag>。
pub fn blob_dir(cache_root : String, repo_id : String) -> String {
  "\{repo_cache_dir(cache_root, repo_id)}/blobs"
}

///|
/// 快照目录：snapshots/<commit-sha>。
pub fn snapshot_dir(
  cache_root : String,
  repo_id : String,
  commit_sha : String,
) -> String {
  "\{repo_cache_dir(cache_root, repo_id)}/snapshots/\{commit_sha}"
}

///|
/// revision -> commit 映射文件：refs/<revision>。
pub fn refs_path(
  cache_root : String,
  repo_id : String,
  revision : String,
) -> String {
  "\{repo_cache_dir(cache_root, repo_id)}/refs/\{revision}"
}

///|
/// 递归创建目录，目录已存在则忽略。
#warnings("-unused_error_type")
pub async fn ensure_dir(path : String) -> Unit raise HubError {
  @fs.mkdir(path, recursive=true) catch {
    _ => ()
  }
}

///|
pub fn dirname(path : String) -> String {
  match path.rev_find("/") {
    None => "."
    Some(0) => "/"
    Some(i) => path[:i].to_owned()
  }
}

///|
#warnings("-unused_error_type")
pub async fn path_exists(path : String) -> Bool raise HubError {
  @fs.exists(path) catch {
    _ => false
  }
}

///|
#warnings("-unused_error_type")
pub async fn read_refs_file(path : String) -> String? raise HubError {
  Some(@fs.read_file(path).text()) catch {
    _ => None
  }
}

///|
#warnings("-unused_error_type")
pub async fn partial_size(path : String) -> Int raise HubError {
  @fs.read_file(path).binary().length() catch {
    _ => 0
  }
}

///|
#warnings("-unused_error_type")
pub async fn remove_file(path : String) -> Unit raise HubError {
  @fs.remove(path) catch {
    _ => ()
  }
}

///|
pub async fn rename_checked(old : String, new : String) -> Unit raise HubError {
  @fs.rename(old, new) catch {
    _ => raise HubError::Io("rename failed: \{old} -> \{new}")
  }
}

///|
/// 写文件，底层 IO 错误统一映射为 HubError::Io。
pub async fn write_file_checked(
  path : String,
  content : &@io.Data,
) -> Unit raise HubError {
  @fs.write_file(path, content) catch {
    _ => raise HubError::Io("write failed: \{path}")
  }
}

///|
/// 创建符号链接，底层 IO 错误统一映射为 HubError::Io。
pub async fn symlink_checked(
  target : String,
  link : String,
) -> Unit raise HubError {
  @fs.symlink(target~, link) catch {
    _ => raise HubError::Io("symlink failed: \{link} -> \{target}")
  }
}
