use anyhow::Result;
use flutter_rust_bridge::frb;

#[frb(opaque)]
pub struct HfTokenizer {
    inner: crate::hf::HfTokenizer,
}

impl HfTokenizer {
    pub fn from_file(path: String, max_tokens: Option<u32>) -> Result<Self> {
        Ok(Self {
            inner: crate::hf::HfTokenizer::from_file(
                &path,
                max_tokens.map(|value| value as usize),
            )?,
        })
    }

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
