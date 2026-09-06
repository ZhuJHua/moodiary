use anyhow::{Result, anyhow};
use tokenizers::{Tokenizer, TruncationParams};

pub struct HfTokenizer {
    inner: Tokenizer,
}

impl HfTokenizer {
    pub fn from_file(path: &str, max_tokens: Option<usize>) -> Result<Self> {
        let mut inner = Tokenizer::from_file(path).map_err(|e| anyhow!("{e}"))?;
        if let Some(max_length) = max_tokens {
            inner
                .with_truncation(Some(TruncationParams {
                    max_length,
                    ..Default::default()
                }))
                .map_err(|e| anyhow!("{e}"))?;
        }
        Ok(Self { inner })
    }

    pub fn encode(&self, text: &str) -> Result<Vec<u32>> {
        Ok(self
            .inner
            .encode(text, true)
            .map_err(|e| anyhow!("{e}"))?
            .get_ids()
            .to_vec())
    }

    pub fn encode_batch(&self, texts: Vec<String>) -> Result<Vec<Vec<u32>>> {
        Ok(self
            .inner
            .encode_batch(texts, true)
            .map_err(|e| anyhow!("{e}"))?
            .into_iter()
            .map(|encoding| encoding.get_ids().to_vec())
            .collect())
    }

    pub fn token_id(&self, token: &str) -> Option<u32> {
        self.inner.token_to_id(token)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture() -> String {
        format!(
            "{}/tests/fixtures/wordpiece_tokenizer.json",
            env!("CARGO_MANIFEST_DIR")
        )
    }

    #[test]
    fn encode_wraps_specials_and_truncates() {
        let tokenizer = HfTokenizer::from_file(&fixture(), Some(5)).unwrap();
        // vocab: 今=4 天=5 很=6 好=7；[CLS]=2 [SEP]=3
        assert_eq!(tokenizer.encode("今天很好").unwrap(), vec![2, 4, 5, 6, 3]);
    }

    #[test]
    fn batch_matches_single() {
        let tokenizer = HfTokenizer::from_file(&fixture(), Some(512)).unwrap();
        let batch = tokenizer
            .encode_batch(vec!["今天".into(), "很好".into()])
            .unwrap();
        assert_eq!(batch[0], tokenizer.encode("今天").unwrap());
        assert_eq!(batch[1], tokenizer.encode("很好").unwrap());
    }

    #[test]
    fn token_id_lookup() {
        let tokenizer = HfTokenizer::from_file(&fixture(), None).unwrap();
        assert_eq!(tokenizer.token_id("[PAD]"), Some(0));
        assert_eq!(tokenizer.token_id("不存在"), None);
    }
}
