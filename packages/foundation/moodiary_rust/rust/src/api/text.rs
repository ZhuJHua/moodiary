use anyhow::Result;
use flutter_rust_bridge::frb;

pub use moodiary_text::TokenizeResult;

/// `cut`（高精度）与 `cut_for_search`（高召回）两组分词结果。
#[frb(mirror(TokenizeResult))]
pub struct _TokenizeResult {
    pub cut: Vec<String>,
    pub cut_for_search: Vec<String>,
}

/// jieba 词典加载约百毫秒，进程启动时在后台线程预热。
#[frb(init)]
pub async fn init_tokenizer() {
    moodiary_text::init_tokenizer().await;
}

#[frb(opaque)]
pub struct Tokenizer {}

impl Tokenizer {
    pub fn tokenize(text: String) -> Result<TokenizeResult> {
        moodiary_text::Tokenizer::tokenize(text)
    }

    /// 一次过桥处理整批，跨篇并行铺满多核。全量重建索引 / 批量导入走这条。
    pub fn tokenize_batch(texts: Vec<String>) -> Result<Vec<TokenizeResult>> {
        moodiary_text::Tokenizer::tokenize_batch(texts)
    }
}
