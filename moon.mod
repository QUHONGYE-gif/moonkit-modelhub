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

name = "QUHONGYE-gif/modelhub"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/QUHONGYE-gif/moonkit-modelhub"

license = "Apache-2.0"

preferred_target = "wasm"

description = "MoonBit × HuggingFace 生态栈：与 huggingface_hub 兼容的 Hub 客户端、张量推理内核、GPT-2 推理与通用 ONNX 图执行器。"

keywords = [
  "huggingface",
  "hub",
  "llm",
  "ml",
  "tensor",
  "transformers",
  "onnx",
  "inference",
  "download",
  "cache",
]

import {
  "moonbitlang/async@0.21.3",
  "howtomakeaname/tokenizers-moonbit@0.4.0",
}
