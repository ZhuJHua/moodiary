import { request } from '@/core/bridge/request'

const LEGACY_PREFIX = 'moodiary-media://media/'

export interface MediaRef {
  name: string
  poster?: boolean
}

const keyOf = (ref: MediaRef): string => (ref.poster ? `${ref.name}#poster` : ref.name)

const resolved = new Map<string, string | null>()
const nameOfUrl = new Map<string, string>()
const pending = new Map<string, Promise<string | null>>()
let batch: { refs: MediaRef[]; done: Promise<Record<string, string | null>> } | null = null

// 同一轮微任务里的请求合并成一次桥调用；Flutter 回的是 file:// 地址，缩略图可能现生成
function enqueue(ref: MediaRef): Promise<Record<string, string | null>> {
  if (!batch) {
    const refs: MediaRef[] = []
    const done = Promise.resolve().then(() => {
      batch = null
      return request<Record<string, string | null>>('resolveMedia', { items: refs })
    })
    batch = { refs, done }
  }
  batch.refs.push(ref)
  return batch.done
}

export function resolveMedia(ref: MediaRef): Promise<string | null> {
  const key = keyOf(ref)
  if (resolved.has(key)) return Promise.resolve(resolved.get(key) ?? null)
  let job = pending.get(key)
  if (!job) {
    job = enqueue(ref).then((urls) => {
      const url = urls[key] ?? null
      resolved.set(key, url)
      if (url) nameOfUrl.set(url, ref.name)
      pending.delete(key)
      return url
    })
    pending.set(key, job)
  }
  return job
}

export function cachedMedia(ref: MediaRef): string | null | undefined {
  return resolved.get(keyOf(ref))
}

export async function fetchMediaName(name: string): Promise<string | null> {
  const res = await request<{ name?: string | null }>('mediaName', { name })
  return typeof res.name === 'string' && res.name ? res.name : null
}

function isImage(name: string): boolean {
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

// 序列化成 HTML（复制到剪贴板）时用已解析的地址；解析不到就保留文件名
export function displaySrc(src: string): string {
  return (isLocalMedia(src) && cachedMedia({ name: src })) || src
}

export function unproxyMedia(url: string): string {
  const name = nameOfUrl.get(url)
  if (name) return name
  return url.startsWith(LEGACY_PREFIX) ? url.slice(LEGACY_PREFIX.length) : url
}
