/// 读取音频文件时长（毫秒）：仅解析容器 / 头部元数据（lofty），不初始化解码器或播放器。
/// 用 `guess_file_type` 按内容而非扩展名判定格式——录音有时是 ADTS AAC 却存成 `.m4a`/`.mp3`，
/// 按扩展名解析会失败。读取失败或时长为 0 时返回 None。
pub fn audio_duration_ms(path: String) -> Option<i64> {
    moodiary_media::audio::audio_duration_ms(path)
}
