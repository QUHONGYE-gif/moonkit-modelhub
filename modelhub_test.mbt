// 黑盒测试：跑的是公共 API。
// 注意：moon test 并行执行测试，每个测试的状态必须互相隔离（闭包捕获局部 Ref）。

///|
test "cache path helpers" {
  inspect(
    @modelhub.repo_cache_dir("/cache", "org/repo"),
    content="/cache/models--org--repo",
  )
  inspect(
    @modelhub.blob_dir("/cache", "org/repo"),
    content="/cache/models--org--repo/blobs",
  )
  inspect(
    @modelhub.snapshot_dir("/cache", "org/repo", "deadbeef"),
    content="/cache/models--org--repo/snapshots/deadbeef",
  )
  inspect(
    @modelhub.refs_path("/cache", "org/repo", "main"),
    content="/cache/models--org--repo/refs/main",
  )
}

///|
test "glob matching" {
  assert_true(@modelhub.matches_glob("config.json", "*.json"))
  assert_true(@modelhub.matches_glob("model.safetensors", "*.safetensors"))
  assert_true(!@modelhub.matches_glob("config.json", "*.bin"))
  assert_true(@modelhub.matches_glob("weights.bin", "weights.??n"))
}

///|
/// 稳定的 mock 服务器：/resolve 永远 302 到 etag=abc123。
#cfg(target="native")
async fn hub_handler(
  request : @http.Request,
  _body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  match request.path {
    "/api/models/gpt2/revision/main" => {
      conn.send_response(200, "OK", extra_headers={
        "Content-Type": "application/json",
      })
      conn.write("{\"sha\":\"commit-main\"}")
    }
    "/gpt2/resolve/main/config.json" =>
      conn.send_response(302, "Found", extra_headers={
        "Location": "/cdn/abc123/config.json",
      })
    "/cdn/abc123/config.json" => {
      conn.send_response(200, "OK", extra_headers={
        "ETag": "\"abc123\"",
        "Content-Type": "application/json",
      })
      conn.write("{\"architectures\":[\"GPT2LMHeadModel\"]}")
    }
    _ => conn.send_response(404, "NotFound")
  }
}

///|
#cfg(target="native")
async fn start_mock(group : @async.TaskGroup[Unit]) -> String {
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  let port = server.addr.port()
  group.spawn_bg(no_wait=true) <| () => { server.run_forever() <| hub_handler }
  "http://127.0.0.1:\{port}"
}

///|
#cfg(target="native")
async test "hf_hub_download writes HF-compatible cache layout" {
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  @async.with_task_group() <| group => {
    let endpoint = start_mock(group)
    let config = @modelhub.HubConfig::new(endpoint, cache)
    let path = @modelhub.hf_hub_download("gpt2", "config.json", config)
    inspect(
      path,
      content="\{cache}/models--gpt2/snapshots/commit-main/config.json",
    )
    let body = @fs.read_file(path).text()
    inspect(body, content="{\"architectures\":[\"GPT2LMHeadModel\"]}")
    let blob = @fs.read_file("\{cache}/models--gpt2/blobs/abc123").text()
    inspect(blob, content=body)
    let refs = @fs.read_file("\{cache}/models--gpt2/refs/main").text()
    inspect(refs, content="commit-main")
  }
}

///|
#cfg(target="native")
async test "missing file raises EntryNotFound" {
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  @async.with_task_group() <| group => {
    let endpoint = start_mock(group)
    let config = @modelhub.HubConfig::new(endpoint, cache)
    let result = try {
      let _ = @modelhub.hf_hub_download("gpt2", "missing.bin", config)
      None
    } catch {
      e => Some(e)
    }
    guard result is Some(@modelhub.HubError::EntryNotFound(_)) else {
      fail("expected EntryNotFound, got \{@debug.to_string(result)}")
    }
  }
}

///|
#cfg(target="native")
async test "cache hit makes no network request" {
  let hits : Ref[Int] = { val: 0, }
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  let endpoint = "http://127.0.0.1:\{server.addr.port()}"
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        hits.val += 1
        match request.path {
          "/api/models/gpt2/revision/main" => {
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
            })
            conn.write("{\"sha\":\"commit-main\"}")
          }
          "/gpt2/resolve/main/config.json" =>
            conn.send_response(302, "Found", extra_headers={
              "Location": "/cdn/abc123/config.json",
            })
          "/cdn/abc123/config.json" => {
            conn.send_response(200, "OK", extra_headers={
              "ETag": "\"abc123\"",
              "Content-Type": "application/json",
            })
            conn.write("{\"architectures\":[\"GPT2LMHeadModel\"]}")
          }
          _ => conn.send_response(404, "NotFound")
        }
      })
    }
    let config = @modelhub.HubConfig::new(endpoint, cache)
    let path1 = @modelhub.hf_hub_download("gpt2", "config.json", config)
    let before = hits.val
    let path2 = @modelhub.hf_hub_download("gpt2", "config.json", config)
    inspect(path2, content=path1)
    assert_eq(hits.val, before)
  }
}

///|
#cfg(target="native")
async test "etag change produces new blob and snapshot" {
  let resolves : Ref[Int] = { val: 0, }
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  let endpoint = "http://127.0.0.1:\{server.addr.port()}"
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        match request.path {
          "/api/models/gpt2/revision/main" => {
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
            })
            conn.write("{\"sha\":\"commit-main\"}")
          }
          "/gpt2/resolve/main/config.json" => {
            resolves.val += 1
            let etag = if resolves.val == 1 { "abc123" } else { "def456" }
            conn.send_response(302, "Found", extra_headers={
              "Location": "/cdn/\{etag}/config.json",
            })
          }
          "/cdn/abc123/config.json" => {
            conn.send_response(200, "OK", extra_headers={
              "ETag": "\"abc123\"",
              "Content-Type": "application/json",
            })
            conn.write("{\"architectures\":[\"GPT2LMHeadModel\"]}")
          }
          "/cdn/def456/config.json" => {
            conn.send_response(200, "OK", extra_headers={
              "ETag": "\"def456\"",
              "Content-Type": "application/json",
            })
            conn.write("{\"n_layer\": 12}")
          }
          _ => conn.send_response(404, "NotFound")
        }
      })
    }
    let config = @modelhub.HubConfig::new(endpoint, cache)
    let snap1 = @modelhub.hf_hub_download("gpt2", "config.json", config)
    @fs.remove(snap1)
    // 第二次 resolve 返回新 etag def456
    let snap2 = @modelhub.hf_hub_download("gpt2", "config.json", config)
    inspect(
      snap2,
      content="\{cache}/models--gpt2/snapshots/commit-main/config.json",
    )
    let body2 = @fs.read_file(snap2).text()
    inspect(body2, content="{\"n_layer\": 12}")
    let old_blob = @fs.read_file("\{cache}/models--gpt2/blobs/abc123").text()
    inspect(old_blob, content="{\"architectures\":[\"GPT2LMHeadModel\"]}")
    let refs = @fs.read_file("\{cache}/models--gpt2/refs/main").text()
    inspect(refs, content="commit-main")
  }
}

///|
#cfg(target="native")
async test "resume download after interruption" {
  let body = "hello world, this is a payload for resume testing"
  let attempts : Ref[Int] = { val: 0, }
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  let endpoint = "http://127.0.0.1:\{server.addr.port()}"
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        match request.path {
          "/api/models/gpt2/revision/main" => {
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
            })
            conn.write("{\"sha\":\"commit-main\"}")
          }
          "/gpt2/resolve/main/config.json" => {
            attempts.val += 1
            conn.send_response(302, "Found", extra_headers={
              "Location": "/cdn/abc123/config.json",
            })
          }
          "/cdn/abc123/config.json" => {
            let range = request.headers.get("range")
            if range is None && attempts.val == 1 {
              // 第一次下载中断：写完 5 字节就断开连接
              conn.send_response(200, "OK", extra_headers={
                "ETag": "\"abc123\"",
                "Content-Type": "text/plain",
              })
              conn.write(body[:5])
              conn.close()
            } else if range is Some(r) {
              let spec = r.strip_prefix("bytes=").unwrap_or(r)
              let dash = spec.find("-").unwrap_or(spec.length())
              let start = @string.parse_int(spec[:dash]) catch { _ => 0 }
              conn.send_response(206, "Partial Content", extra_headers={
                "ETag": "\"abc123\"",
                "Content-Type": "text/plain",
              })
              conn.write(body[start:])
            } else {
              conn.send_response(200, "OK", extra_headers={
                "ETag": "\"abc123\"",
                "Content-Type": "text/plain",
              })
              conn.write(body)
            }
          }
          _ => conn.send_response(404, "NotFound")
        }
      })
    }
    let config = @modelhub.HubConfig::new(endpoint, cache)
    let interrupted = try {
      let _ = @modelhub.hf_hub_download("gpt2", "config.json", config)
      None
    } catch {
      e => Some(e)
    }
    guard interrupted is Some(@modelhub.HubError::Io(_)) else {
      fail("expected interruption, got \{@debug.to_string(interrupted)}")
    }
    let path = @modelhub.hf_hub_download("gpt2", "config.json", config)
    let content = @fs.read_file(path).text()
    inspect(content, content=body)
  }
}

///|
#cfg(target="native")
async test "snapshot_download downloads all siblings" {
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  let endpoint = "http://127.0.0.1:\{server.addr.port()}"
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        match request.path {
          "/api/models/gpt2/revision/main" => {
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
            })
            conn.write(
              "{\"sha\":\"commit-main\",\"siblings\":[{\"rfilename\":\"config.json\"},{\"rfilename\":\"tokenizer.json\"}]}",
            )
          }
          "/gpt2/resolve/main/config.json" =>
            conn.send_response(302, "Found", extra_headers={
              "Location": "/cdn/aaa/config.json",
            })
          "/gpt2/resolve/main/tokenizer.json" =>
            conn.send_response(302, "Found", extra_headers={
              "Location": "/cdn/bbb/tokenizer.json",
            })
          "/cdn/aaa/config.json" => {
            conn.send_response(200, "OK", extra_headers={
              "ETag": "\"aaa\"",
              "Content-Type": "text/plain",
            })
            conn.write("config")
          }
          "/cdn/bbb/tokenizer.json" => {
            conn.send_response(200, "OK", extra_headers={
              "ETag": "\"bbb\"",
              "Content-Type": "text/plain",
            })
            conn.write("tokenizer")
          }
          _ => conn.send_response(404, "NotFound")
        }
      })
    }
    let config = @modelhub.HubConfig::new(endpoint, cache)
    let snap = @modelhub.snapshot_download("gpt2", config, None, None)
    inspect(snap, content="\{cache}/models--gpt2/snapshots/commit-main")
    let config_body = @fs.read_file("\{snap}/config.json").text()
    inspect(config_body, content="config")
    let tok_body = @fs.read_file("\{snap}/tokenizer.json").text()
    inspect(tok_body, content="tokenizer")
  }
}

///|
#cfg(target="native")
async test "snapshot_download respects ignore patterns" {
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  let endpoint = "http://127.0.0.1:\{server.addr.port()}"
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        match request.path {
          "/api/models/gpt2/revision/main" => {
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
            })
            conn.write(
              "{\"sha\":\"commit-main\",\"siblings\":[{\"rfilename\":\"config.json\"},{\"rfilename\":\"tokenizer.json\"}]}",
            )
          }
          "/gpt2/resolve/main/config.json" =>
            conn.send_response(302, "Found", extra_headers={
              "Location": "/cdn/aaa/config.json",
            })
          "/cdn/aaa/config.json" => {
            conn.send_response(200, "OK", extra_headers={
              "ETag": "\"aaa\"",
              "Content-Type": "text/plain",
            })
            conn.write("config")
          }
          _ => conn.send_response(404, "NotFound")
        }
      })
    }
    let config = @modelhub.HubConfig::new(endpoint, cache)
    let snap = @modelhub.snapshot_download(
      "gpt2",
      config,
      None,
      Some(["tokenizer.json"]),
    )
    let config_body = @fs.read_file("\{snap}/config.json").text()
    inspect(config_body, content="config")
    let missing = Some(@fs.read_file("\{snap}/tokenizer.json").text()) catch {
      _ => None
    }
    guard missing is None else {
      fail("tokenizer.json should have been ignored")
    }
  }
}

///|
#cfg(target="native")
async test "gated repo requires token" {
  let auth_seen : Ref[String?] = { val: None, }
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  let endpoint = "http://127.0.0.1:\{server.addr.port()}"
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        match request.path {
          "/api/models/gpt2/revision/main" => {
            let auth = request.headers.get("authorization")
            auth_seen.val = auth
            if auth is None {
              conn.send_response(401, "Unauthorized")
            } else {
              conn.send_response(200, "OK", extra_headers={
                "Content-Type": "application/json",
              })
              conn.write("{\"sha\":\"commit-main\",\"siblings\":[]}")
            }
          }
          _ => conn.send_response(404, "NotFound")
        }
      })
    }
    let config = @modelhub.HubConfig::new(endpoint, cache)
    let denied = try {
      let _ = @modelhub.snapshot_download("gpt2", config, None, None)
      None
    } catch {
      e => Some(e)
    }
    guard denied is Some(@modelhub.HubError::GatedRepo(_)) else {
      fail("expected GatedRepo, got \{@debug.to_string(denied)}")
    }
    let authed = config.with_token("hf_test_token")
    let _ = @modelhub.snapshot_download("gpt2", authed, None, None)
    guard auth_seen.val is Some(a) && a.has_prefix("Bearer hf_test_token") else {
      fail("authorization header not sent: \{@debug.to_string(auth_seen.val)}")
    }
  }
}

///|
#cfg(target="native")
async test "offline mode: cold cache raises Offline, warm cache hits" {
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  @async.with_task_group() <| group => {
    let endpoint = start_mock(group)
    let online = @modelhub.HubConfig::new(endpoint, cache)
    let path1 = @modelhub.hf_hub_download("gpt2", "config.json", online)
    let offline = online.with_offline(true)
    let path2 = @modelhub.hf_hub_download("gpt2", "config.json", offline)
    inspect(path2, content=path1)
  }
  let cold = @modelhub.HubConfig::new("http://127.0.0.1:1", "\{root}/cold").with_offline(
    true,
  )
  let denied = try {
    let _ = @modelhub.hf_hub_download("gpt2", "config.json", cold)
    None
  } catch {
    e => Some(e)
  }
  guard denied is Some(@modelhub.HubError::Offline(_)) else {
    fail("expected Offline, got \{@debug.to_string(denied)}")
  }
}

///|
#cfg(target="native")
async test "model_info parses metadata and maps 404" {
  let root = @fs.tmpdir(prefix="modelhub-test")
  let cache = "\{root}/hub"
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  let endpoint = "http://127.0.0.1:\{server.addr.port()}"
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        match request.path {
          "/api/models/gpt2" => {
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
            })
            conn.write(
              "{\"id\":\"gpt2\",\"sha\":\"commit-main\",\"private\":false,\"downloads\":1000,\"likes\":5,\"siblings\":[{\"rfilename\":\"config.json\"}]}",
            )
          }
          "/api/models/unknown" => conn.send_response(404, "NotFound")
          _ => conn.send_response(404, "NotFound")
        }
      })
    }
    let config = @modelhub.HubConfig::new(endpoint, cache)
    let info = @modelhub.model_info("gpt2", config)
    inspect(info.id, content="gpt2")
    assert_eq(info.downloads, 1000)
    assert_eq(info.likes, 5)
    assert_true(!info.private)
    inspect(info.siblings[0], content="config.json")
    let missing = try {
      let _ = @modelhub.model_info("unknown", config)
      None
    } catch {
      e => Some(e)
    }
    guard missing is Some(@modelhub.HubError::RevisionNotFound(_)) else {
      fail("expected RevisionNotFound, got \{@debug.to_string(missing)}")
    }
  }
}
