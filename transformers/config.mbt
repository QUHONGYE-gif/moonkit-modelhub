// transformers：GPT-2 配置解析。

///|
pub struct Gpt2Config {
  vocab_size : Int
  n_ctx : Int
  n_embd : Int
  n_head : Int
  n_layer : Int
  intermediate : Int
  eps : Double
  bos_token_id : Int
  eos_token_id : Int
}

///|
fn int_field(obj : Map[String, Json], key : String, default : Int) -> Int {
  match obj.get(key) {
    Some(Json::Number(d, ..)) => d.to_int()
    _ => default
  }
}

///|
fn double_field(
  obj : Map[String, Json],
  key : String,
  default : Double,
) -> Double {
  match obj.get(key) {
    Some(Json::Number(d, ..)) => d
    _ => default
  }
}

///|
/// 从 config.json 解析 GPT-2 配置。
pub fn parse_config(json : Json) -> Gpt2Config raise @nn.TensorError {
  let obj = match json {
    Json::Object(o) => o
    _ => raise @nn.TensorError::ShapeMismatch("config must be JSON object")
  }
  {
    vocab_size: int_field(obj, "vocab_size", 50257),
    n_ctx: int_field(obj, "n_ctx", 1024),
    n_embd: int_field(obj, "n_embd", 768),
    n_head: int_field(obj, "n_head", 12),
    n_layer: int_field(obj, "n_layer", 12),
    intermediate: int_field(obj, "intermediate_size", 3072),
    eps: double_field(obj, "layer_norm_epsilon", 1.0e-5),
    bos_token_id: int_field(obj, "bos_token_id", 50256),
    eos_token_id: int_field(obj, "eos_token_id", 50256),
  }
}
