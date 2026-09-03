//! 文本分词：jieba（搜索索引与关键词，`jieba.rs`）与 HF tokenizer.json（ONNX 推理侧分词，`hf.rs`）。
//! `api/` 是 FRB 门面，唯一认识 `flutter_rust_bridge` 的地方。

pub mod api;
mod frb_generated;
pub mod hf;
pub mod jieba;
