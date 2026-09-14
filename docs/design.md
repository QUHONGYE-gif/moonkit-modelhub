# modelhub 设计草案

> 状态：draft，随 spike 结论更新。任何对本文件的修改应先讨论再落代码。

## 推理内核（moonkit/nn，阶段 5）

**选型结论（2026-09-14）：自研，不复用 moon-tensor / mbtorch。**

现状摘要：moon-tensor 是早期的裸算子集合（GEMM/Conv1D/激活/LayerNorm，
0 star、API 未定）；mbtorch 面向训练 + 模式匹配导入 ONNX，不在我们的
推理内核需求路径上。GPT-2 推理所需算子集很小（matmul / gelu / softmax /
LayerNorm / RMSNorm / attention），自研成本低、可控性强，且与 modelhub 的
「原创 + golden 对照」叙事一致。

约定：

- 数值类型 MVP 用 **Double(f64)**：与 numpy 默认 double 直接对照 golden，
  免去 f32 舍入噪音；transformers.mbt 阶段再评估 f32 化。
- 行主序、纯函数风格（算子返回新 Tensor）；性能优化不在本期（朴素实现优先）。
- golden 数据一律由 `scripts/gen_nn_golden.py`（numpy）生成，测试逐元素
  对照（默认容差 1e-5）。

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

## HTTP 层（已定：moonbitlang/async，2026-09-14 spike 结论）

**选型：`moonbitlang/async@0.21.3` 的 `http` 包作为唯一传输层。** spike 验证结果
（代码在 `cmd/spike/`，验收见 issue 01）：

- native 后端对 `https://hf-mirror.com/api/models/gpt2` 的 HTTPS GET 返回 200，
  TLS 可用（OpenSSL 后端；wasm 目标走 WASI TLS，js 走 fetch，三后端都有 client）；
- 自定义 Header（Range）正常传递，本地 mock 的 200/302 响应均正常；
- **async 客户端不自动跟随重定向**，`/resolve` 会 302 到 CDN，因此 modelhub
  自实现 3xx 循环（`http_client.mbt` 的 `get_follow`）；
- `@http.get_stream` 提供流式读取，阶段 1 的断点续传将基于它实现。

候选记录（结论落定前的备选，均不再需要）：

1. ✅ `moonbitlang/async` 的 http 模块——选定
2. ❌ 后端抽象 trait（libcurl FFI + js fetch）——async 已覆盖三后端
3. ❌ 自研最小 HTTPS 客户端——放弃

注意：新版 MoonBit 的错误系统要求每个可能抛错的调用显式吸收（`try/catch`），
`http_client.mbt` / `cache.mbt` 已把底层错误统一映射为 `HubError`。

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
