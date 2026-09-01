use anyhow::Result;
use flutter_rust_bridge::frb;

/// HF tokenizer.json 分词器（WordPiece / SentencePiece / BPE），ONNX 推理侧用。
#[frb(opaque)]
pub struct HfTokenizer {
    inner: moodiary_hf_tokenizer::HfTokenizer,
}

impl HfTokenizer {
    /// [max_tokens] 含特殊 token，超出按 LongestFirst 截断。
    pub fn from_file(path: String, max_tokens: Option<u32>) -> Result<Self> {
        Ok(Self {
            inner: moodiary_hf_tokenizer::HfTokenizer::from_file(
                &path,
                max_tokens.map(|value| value as usize),
            )?,
        })
    }

    /// 含特殊 token（CLS/SEP 随 json 的 post-processor）。
    pub fn encode(&self, text: String) -> Result<Vec<u32>> {
        self.inner.encode(&text)
    }

    pub fn encode_batch(&self, texts: Vec<String>) -> Result<Vec<Vec<u32>>> {
        self.inner.encode_batch(texts)
    }

    pub fn token_id(&self, token: String) -> Option<u32> {
        self.inner.token_id(&token)
    }
}
