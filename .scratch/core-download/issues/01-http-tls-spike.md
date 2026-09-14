Status: ready-for-human

## Parent

`.scratch/core-download/PRD.md`

## What to build

用 `moonbitlang/async` 搭建最小 HTTP 客户端：发起 GET、自定义 Header（Range）、
跟随重定向、流式读取响应体。分别对本地 mock 服务器（HTTP）和 hf-mirror（HTTPS）
各完成一次请求，验证 native 后端的 TLS 能力，并把结论写入 `docs/design.md` 的
「HTTP 层」章节。若 async 不能满足要求，需给出备选方案（js fetch / libcurl FFI）
的验证结果与建议。

## Acceptance criteria

- [x] `moonbitlang/async` 加入依赖，`moon test` 在默认 wasm 与 native 目标均通过
- [x] 本地 HTTP mock 返回 200，响应体字节与期望一致
- [x] 对 `https://hf-mirror.com` 的 HTTPS GET 在 native 后端成功（或明确记录不可用及兜底方案）
- [x] Range 请求头被 mock 记录；302 重定向被正确跟随
- [x] `docs/design.md` 的 HTTP 层章节更新为最终选型结论

## Blocked by

None - can start immediately

## Comments

- 2026-09-14 完成。选型结论：`moonbitlang/async@0.21.3`（详见 `docs/design.md`）。
