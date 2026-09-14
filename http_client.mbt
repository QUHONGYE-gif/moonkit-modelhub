// 传输层：基于 moonbitlang/async 的最小 HTTP GET 客户端。
// spike 结论（2026-09-14）：async 客户端支持 native/wasm/js 三后端、TLS 可用，
// 但不自动跟随重定向，因此这里补上 3xx 循环（HF 的 /resolve 会 302 到 CDN）。

///|
/// 取 URL 的 origin 部分（scheme://host[:port]），用于拼接相对 Location。
fn origin(url : String) -> String {
  let scheme_end = url.find("://").unwrap_or(0) + 3
  let rest = url[scheme_end:]
  match rest.find("/") {
    None => url
    Some(i) => url[:scheme_end + i].to_owned()
  }
}

///|
/// 发起 GET 并手动跟随重定向，返回最终状态码、响应头与响应体字节。
pub async fn get_follow(
  url : String,
  headers : @http.Headers,
  max_redirects : Int,
) -> (Int, @http.Headers, Bytes) raise HubError {
  let mut current = url
  let mut remaining = max_redirects
  while true {
    let (resp, body) = @http.get(current, headers~) catch {
      _ => raise HubError::Io("GET failed: \{current}")
    }
    if resp.code >= 300 && resp.code < 400 && remaining > 0 {
      let loc = match resp.headers.get("location") {
        Some(l) => l
        None => raise HubError::BadStatus(resp.code, current)
      }
      current = if loc.has_prefix("http") { loc } else { origin(current) + loc }
      remaining -= 1
    } else {
      return (resp.code, resp.headers, body.binary())
    }
  }
  abort("unreachable")
}

///|
/// 与 get_follow 相同，但流式读取响应体：返回最终响应头与客户端 reader。
pub async fn get_stream_follow(
  url : String,
  headers : @http.Headers,
  max_redirects : Int,
) -> (Int, @http.Headers, @http.Client) raise HubError {
  let mut current = url
  let mut remaining = max_redirects
  while true {
    let (resp, client) = @http.get_stream(current, headers~) catch {
      _ => raise HubError::Io("GET failed: \{current}")
    }
    if resp.code >= 300 && resp.code < 400 && remaining > 0 {
      let loc = match resp.headers.get("location") {
        Some(l) => l
        None => {
          client.close()
          raise HubError::BadStatus(resp.code, current)
        }
      }
      client.close()
      current = if loc.has_prefix("http") { loc } else { origin(current) + loc }
      remaining -= 1
    } else {
      return (resp.code, resp.headers, client)
    }
  }
  abort("unreachable")
}
