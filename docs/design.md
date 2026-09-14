# modelhub 设计草案

> 状态：draft，随 spike 结论更新。任何对本文件的修改应先讨论再落代码。

## 核心 API 草案

```moonbit
///| 从仓库下载单个文件，返回本地路径（命中缓存时不做网络请求）
pub fn hf_hub_download(
  repo_id : String,
  filename : String,
  revision~ : String = "main",
  cache_dir~ : String? = None,
  local_files_only~ : Bool = false,
  subfolder~ : String = "",
) -> String!HubError

///| 下载整个模型快照，返回快照目录
pub fn snapshot_download(
  repo_id : String,
  revision~ : String = "main",
  cache_dir~ : String? = None,
  allow_patterns~ : Array[String]? = None,
  ignore_patterns~ : Array[String]? = None,
) -> String!HubError

///| 查询仓库元信息（siblings 等）
pub fn model_info(repo_id : String) -> RepoInfo!HubError
```

## 缓存布局（与 huggingface_hub parity）

```
~/.cache/huggingface/hub/
└── models--gpt2/
    ├── blobs/
    │   ├── <etag-A>            # 内容寻址存储，全仓库去重
    │   └── <etag-B>
    ├── snapshots/
    │   └── <commit-hash>/
    │       ├── config.json -> ../../blobs/<etag-A>
    │       └── pytorch_model.bin -> ../../blobs/<etag-B>
    └── refs/
        └── main                # 内容为 commit hash
```

关键点：

- `blobs` 按 etag（SHA256）寻址，同一文件在不同 revision 间共享；
- `snapshots/<commit>` 内使用相对符号链接指向 blobs；
- `refs/<revision>` 记录 revision 解析出的 commit；
- 另有 `.no_exist/`、`.incomplete/`（断点续传临时文件）等官方细节需逐一对照实现。

## 环境变量

| 变量 | 作用 | 对齐 huggingface_hub |
|---|---|---|
| `HF_ENDPOINT` | 自定义端点/镜像 | ✅ |
| `HF_TOKEN` / `HUGGING_FACE_HUB_TOKEN` | 认证 token | ✅ |
| `HF_HUB_CACHE` | 缓存根目录 | ✅ |
| `HF_HUB_OFFLINE` | 离线模式，禁网络 | ✅ |
| `HF_HUB_DOWNLOAD_TIMEOUT` | 下载超时 | ✅ |

## HTTP 层（待 spike 定论）

三个候选，按优先级：

1. `moonbitlang/async` 的 http 模块（native/wasm 后端统一，官方维护）；
2. 后端抽象 trait：native 走 libcurl FFI，wasm/js 走 fetch——牺牲"无 FFI"换取稳妥；
3. 自研最小 HTTPS 客户端——工作量过大，不推荐。

spike 实验（09-15 前完成）：用每个候选对 `https://hf-mirror.com` 完成一次带 Range 头的
GET 请求，验证 TLS、重定向、流式读取三件事。

## 测试策略

1. **Mock 服务器**：本地 Python HTTP 服务器，模拟 `/api/models/<repo>/revision/<rev>`
   与 `/resolve` 端点，支持 etag、Range、401/403、302 重定向、断点续传场景。
2. **parity 测试**：对同一 mock 服务器，分别用我们的实现与 Python `huggingface_hub`
   下载同一仓库，断言两边生成的缓存目录树与文件内容完全一致。
3. **单元测试**：revision 解析、etag 校验、pattern 过滤、错误映射等纯函数全覆盖。
4. **离线测试**：预热缓存后以 `HF_HUB_OFFLINE=1` 运行，断言零网络请求。

## 错误模型

`HubError` 枚举：`RevisionNotFound`、`EntryNotFound`、`GatedRepo`、`OfflineMode`、
`Connection`、`CacheCorrupted`。错误消息尽量对齐 huggingface_hub 的文案，
便于用户迁移。
