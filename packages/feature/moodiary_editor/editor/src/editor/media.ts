// 本地媒体在正文里以文件名引用（`![](image-xxx.jpg)`，也是落库形态）。显示时由自定义 Image
// 扩展的 renderHTML 加上媒体服务前缀拼出完整 URL：前缀来自 boot.mediaBase（Flutter 本地回环 HTTP 服务，
// 按需从磁盘读字节，视频取缩略图），每次启动端口 / token 随机。读出 markdown 时再把前缀剥回
// 裸文件名，确保落库形态永远是裸文件名。
//
// 旧实现走自定义 scheme `moodiary-media://media/`（inappwebview 拦截）。保留作默认值与
// 兜底剥除，兼容旧版本可能把该前缀带进落库 markdown 的历史残留。

const LEGACY_PREFIX = 'moodiary-media://media/'

let mediaPrefix = LEGACY_PREFIX

/** boot 后设置实际媒体前缀（如 `http://127.0.0.1:PORT/<token>/media/`），编辑器构建前调用。 */
export function setMediaPrefix(base: string): void {
  if (base) mediaPrefix = base.endsWith('/') ? base : `${base}/`
}

export function getMediaPrefix(): string {
  return mediaPrefix
}

/**
 * 拼出本地媒体的显示 URL。[poster] = true 时取视频海报（缩略图）—— 本地服务对带 `?poster=1`
 * 的请求返回 thumbnail jpeg；否则返回原片字节（支持 Range，供 <audio>/<video> 内联播放）。
 */
export function mediaUrl(name: string, opts?: { poster?: boolean }): string {
  const base = mediaPrefix + name
  return opts?.poster ? `${base}?poster=1` : base
}

/** 本地媒体按文件名前缀分三类（与 Flutter 落库命名一致：image-/audio-/video-）。 */
export function isImage(name: string): boolean {
  return /^image-/.test(name)
}
export function isAudio(name: string): boolean {
  return /^audio-/.test(name)
}
export function isVideo(name: string): boolean {
  return /^video-/.test(name)
}

/** 是否本地媒体文件名（区别于外链 http(s) 图片）。 */
export function isLocalMedia(name: string): boolean {
  return isImage(name) || isAudio(name) || isVideo(name)
}

/** 把显示 URL 反解回原始文件名（外链原样返回）。 */
export function unproxyMedia(url: string): string {
  if (url.startsWith(mediaPrefix)) return url.slice(mediaPrefix.length)
  return url.startsWith(LEGACY_PREFIX) ? url.slice(LEGACY_PREFIX.length) : url
}

/**
 * 把整段 markdown 里的媒体前缀剥回裸文件名。自定义 Image 扩展的 renderHTML 在渲染时给本地图片名
 * 加上前缀以供显示；但 markdown 序列化兜底可能把前缀带回。落库前统一剥除（含旧 scheme
 * 前缀兜底）。用 split/join 而非 String.replaceAll —— 构建目标 es2019，老 Android WebView
 * 无 replaceAll。
 */
export function stripMediaPrefix(markdown: string): string {
  const stripped = markdown.split(mediaPrefix).join('')
  return mediaPrefix === LEGACY_PREFIX
    ? stripped
    : stripped.split(LEGACY_PREFIX).join('')
}
