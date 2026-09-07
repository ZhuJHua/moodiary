const LEGACY_PREFIX = 'moodiary-media://media/'

let mediaPrefix = LEGACY_PREFIX

export function setMediaPrefix(base: string): void {
  if (base) mediaPrefix = base.endsWith('/') ? base : `${base}/`
}

export function mediaUrl(name: string, opts?: { poster?: boolean }): string {
  const base = mediaPrefix + name
  return opts?.poster ? `${base}?poster=1` : base
}

let mediaInfoPrefix = ''
let fallbackAudioName = '音频'

export function setMediaInfoPrefix(base: string): void {
  if (base) mediaInfoPrefix = base.endsWith('/') ? base : `${base}/`
}

export function setAudioDefaultName(name: string): void {
  if (name) fallbackAudioName = name
}

export function audioDefaultName(): string {
  return fallbackAudioName
}

export async function fetchMediaName(name: string): Promise<string | null> {
  if (!mediaInfoPrefix) return null
  try {
    const res = await fetch(mediaInfoPrefix + name)
    if (!res.ok) return null
    const data = (await res.json()) as { name?: string | null }
    return typeof data.name === 'string' && data.name ? data.name : null
  } catch {
    return null
  }
}

export function isImage(name: string): boolean {
  return /^image-/.test(name)
}
export function isAudio(name: string): boolean {
  return /^audio-/.test(name)
}
export function isVideo(name: string): boolean {
  return /^video-/.test(name)
}

export function isLocalMedia(name: string): boolean {
  return isImage(name) || isAudio(name) || isVideo(name)
}

export function displaySrc(src: string): string {
  return isLocalMedia(src) ? mediaPrefix + src : src
}

export function unproxyMedia(url: string): string {
  if (url.startsWith(mediaPrefix)) return url.slice(mediaPrefix.length)
  return url.startsWith(LEGACY_PREFIX) ? url.slice(LEGACY_PREFIX.length) : url
}

// 构建目标 es2019，老 Android WebView 无 String.replaceAll，用 split/join 代替
export function stripMediaPrefix(markdown: string): string {
  const stripped = markdown.split(mediaPrefix).join('')
  return mediaPrefix === LEGACY_PREFIX
    ? stripped
    : stripped.split(LEGACY_PREFIX).join('')
}
