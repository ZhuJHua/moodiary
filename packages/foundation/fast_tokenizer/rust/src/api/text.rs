use anyhow::Result;
use flutter_rust_bridge::frb;

pub use crate::jieba::TokenizeResult;

#[frb(mirror(TokenizeResult))]
pub struct _TokenizeResult {
    pub cut: Vec<String>,
    pub cut_for_search: Vec<String>,
}

#[frb(opaque)]
pub struct Tokenizer {}

impl Tokenizer {
    pub fn tokenize(text: String) -> Result<TokenizeResult> {
        crate::jieba::Tokenizer::tokenize(text)
    }

    pub fn tokenize_batch(texts: Vec<String>) -> Result<Vec<TokenizeResult>> {
        crate::jieba::Tokenizer::tokenize_batch(texts)
    }
}
