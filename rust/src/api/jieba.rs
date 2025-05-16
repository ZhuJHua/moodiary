use anyhow::{Context, Ok, Result};
use flutter_rust_bridge::frb;
use jieba_rs::{Jieba, KeywordExtract, TextRank, TfIdf};
use once_cell::sync::OnceCell;
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::OnceCell as AsyncOnceCell;

#[frb(opaque)]
pub struct JiebaRs {
    inner: Jieba,
    tfidf: OnceCell<TfIdf>,
    text_rank: OnceCell<TextRank>,
}

#[derive(Debug, Clone)]
#[frb(opaque)]
pub struct JiebaKeyword {
    pub keyword: String,
    pub weight: f64,
}

static GLOBAL_JIEBA: AsyncOnceCell<Arc<JiebaRs>> = AsyncOnceCell::const_new();

#[frb(init)]
pub async fn init_jieba() {
    JiebaRs::init_global().await;
}

impl JiebaRs {
    fn new() -> Self {
        Self {
            inner: Jieba::new(),
            tfidf: OnceCell::new(),
            text_rank: OnceCell::new(),
        }
    }

    async fn init_global() {
        GLOBAL_JIEBA
            .get_or_init(|| async {
                let instance = JiebaRs::new();
                Arc::new(instance)
            })
            .await;
    }

    fn get_instance() -> Result<Arc<JiebaRs>> {
        GLOBAL_JIEBA
            .get()
            .cloned()
            .context("JiebaRs is not initialized. Please call init_global() first.")
    }

    pub fn cut(text: String, hmm: bool) -> Result<Vec<String>> {
        let jieba = Self::get_instance()?;
        Ok(jieba
            .inner
            .cut(&text, hmm)
            .iter()
            .map(|s| s.to_string())
            .collect())
    }

    pub fn cut_all(text: String) -> Result<Vec<String>> {
        let jieba = Self::get_instance()?;
        let result: HashSet<String> = jieba
            .inner
            .cut_all(&text)
            .iter()
            .map(|s| s.to_string())
            .collect();
        Ok(result.into_iter().collect())
    }

    pub fn cut_for_search(text: String, hmm: bool) -> Result<Vec<String>> {
        let jieba = Self::get_instance()?;
        let result: HashSet<String> = jieba
            .inner
            .cut_for_search(&text, hmm)
            .iter()
            .map(|s| s.to_string())
            .collect();
        Ok(result.into_iter().collect())
    }

    pub fn extract_keywords_tfidf(
        text: String,
        top_k: usize,
        allowed_pos: Vec<String>,
    ) -> Result<Vec<JiebaKeyword>> {
        let jieba = Self::get_instance()?;
        let tfidf = jieba
            .tfidf
            .get_or_try_init(|| Ok(TfIdf::default()))
            .context("Failed to initialize TF-IDF")?;

        let keywords = tfidf.extract_keywords(&jieba.inner, &text, top_k, allowed_pos);
        Ok(Self::convert_keywords(keywords))
    }

    pub fn extract_keywords_text_rank(
        text: String,
        top_k: usize,
        allowed_pos: Vec<String>,
    ) -> Result<Vec<JiebaKeyword>> {
        let jieba = Self::get_instance()?;
        let text_rank = jieba
            .text_rank
            .get_or_try_init(|| Ok(TextRank::default()))
            .context("Failed to initialize TextRank")?;

        let keywords = text_rank.extract_keywords(&jieba.inner, &text, top_k, allowed_pos);
        Ok(Self::convert_keywords(keywords))
    }

    fn convert_keywords(keywords: Vec<jieba_rs::Keyword>) -> Vec<JiebaKeyword> {
        keywords
            .into_iter()
            .map(|k| JiebaKeyword {
                keyword: k.keyword,
                weight: k.weight,
            })
            .collect()
    }
}
