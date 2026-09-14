// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "moonkit/modelhub"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/QUHONGYE-gif/moonkit-modelhub"

license = "Apache-2.0"

preferred_target = "wasm"

description = "MoonBit 的 HuggingFace Hub 客户端：与 huggingface_hub 兼容的模型下载、修订版本解析与缓存管理。"

keywords = [ "huggingface", "hub", "llm", "ml", "download", "cache" ]

import {
  "moonbitlang/async@0.21.3",
}
