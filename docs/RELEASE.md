# 发布指南（mooncakes）

## 当前状态

模块名：`QUHONGYE-gif/modelhub`（含四个子包：顶层 modelhub、`nn`、`transformers`、`onnx`）。

已完成准备：

- `moon.mod` 元数据：description / keywords / license / repository / readme；
- 根 README（生态栈总览）与各子包 README；
- Apache-2.0 许可证。

## 发布前自检

```bash
conda activate moonbit
moon check --target native     # 0 error / 0 warning
moon test --target native      # 31/31
moon test                      # wasm 21/21
moon publish --dry-run         # 打包预检（不真正上传）
```

已验证：`moon package` 通过（Check passed，产出
`_build/publish/moonkit-modelhub-0.1.0.zip`，约 120 KB）。
`moon publish --dry-run` 会要求先登录，因此登录前的最终自检以 `moon package` 为准。

## 正式发布

需要 mooncakes 账号（首次要先在 https://mooncakes.io 注册并登录）：

```bash
moon login                     # 浏览器授权
moon publish                   # 上传 moonsky/modelhub 当前版本
```

版本号在 `moon.mod` 的 `version` 字段（当前 0.1.0）；后续每次发布需要递增。

## 备注

- CLI（`cmd/*`）与示例（`examples/*`）是 native-only 包，不影响模块的整体发布
  （MoonBit 按包声明 target，wasm 目标下跳过它们）；
- `bench`、`scripts`、`tests/fixtures` 会随源码仓库提供，不参与包发布；
- 发布后可在 mooncakes 页面确认文档渲染与包版本。
