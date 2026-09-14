// HTTP/TLS spike for modelhub (issue 01-http-tls-spike).
// 验证 async 的 HTTP 客户端：GET、自定义 Header、跟随重定向、HTTPS(TLS)。

///|
fn origin(url : String) -> String {
  let scheme_end = url.find("://").unwrap_or(0) + 3
  let rest = url[scheme_end:]
  match rest.find("/") {
    None => url
    Some(i) => url[:scheme_end + i].to_owned()
  }
}

///|
/// 发起 GET，手动跟随 3xx 重定向（async 的客户端不自动跟随）。
async fn fetch(
  url : String,
  headers : @http.Headers,
  max_redirects? : Int = 5,
) -> (Int, String) {
  let mut current = url
  let mut remaining = max_redirects
  while true {
    let (resp, body) = @http.get(current, headers~)
    if resp.code >= 300 && resp.code < 400 && remaining > 0 {
      let loc = resp.headers.get("location")
      guard loc is Some(l) else { return (resp.code, body.text()) }
      current = if l.has_prefix("http") { l } else { origin(current) + l }
      remaining -= 1
    } else {
      return (resp.code, body.text())
    }
  }
  abort("unreachable")
}

///|
async fn main {
  let matches = @argparse.Command(
    "spike",
    about="HTTP/TLS spike for modelhub",
    options=[
      OptionArg("range", long="range", about="value for the Range header"),
    ],
    positionals=[
      PositionArg(
        "url",
        about="URL to GET",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  ).parse()
  guard matches.values is { "url": [url], .. } else { fail("no URL given") }
  let range = match matches.values {
    { "range": [r], .. } => Some(r)
    _ => None
  }
  let headers : @http.Headers = match range {
    None => Map([])
    Some(r) => { "Range": r }
  }
  let (code, text) = fetch(url, headers)
  println("status: \{code}")
  let shown = if text.length() > 300 { text[:300].to_owned() } else { text }
  println(shown)
}
