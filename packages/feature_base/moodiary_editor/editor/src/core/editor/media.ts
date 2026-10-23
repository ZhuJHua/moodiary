import { request } from '@/core/bridge/request'

interface MediaRef {
  name: string
  poster?: boolean
}

const keyOf = (ref: MediaRef): string => (ref.poster ? `${ref.name}#poster` : ref.name)

const resolved = new Map<string, string>()
const nameOfUrl = new Map<string, string>()
const pending = new Map<string, Promise<string | null>>()
let batch: { refs: MediaRef[]; done: Promise<Record<string, string | null>> } | null = null

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
      if (url) {
        resolved.set(key, url)
        nameOfUrl.set(url, ref.name)
      }
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

type MediaKind = 'image' | 'audio' | 'video' | 'file'

export function mediaKindOf(name: string): MediaKind | null {
  const m = /^(image|audio|video|file)-/.exec(name)
  return m ? (m[1] as MediaKind) : null
}

export function isLocalMedia(name: string): boolean {
  const kind = mediaKindOf(name)
  return kind === 'image' || kind === 'audio' || kind === 'video'
}

export function displaySrc(src: string): string {
  return (isLocalMedia(src) && cachedMedia({ name: src })) || src
}

// 查不到映射的本地地址只认媒体名，缓存派生图等路径不能落进正文
export function unproxyMedia(url: string): string {
  const known = nameOfUrl.get(url)
  if (known) return known
  if (!/^file:/i.test(url)) return url
  try {
    const base = decodeURIComponent(url.slice(url.lastIndexOf('/') + 1))
    return mediaKindOf(base) ? base : ''
  } catch {
    return ''
  }
}

export function fileExtension(name: string): string {
  const dot = name.lastIndexOf('.')
  return dot > 0 && dot < name.length - 1 ? name.slice(dot + 1) : ''
}

export function formatFileSize(size: number | null | undefined): string {
  if (typeof size !== 'number' || !Number.isFinite(size) || size < 0) return ''
  if (size < 1024) return `${size} B`
  const units = ['KB', 'MB', 'GB']
  let value = size / 1024
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit += 1
  }
  return `${value >= 10 ? Math.round(value) : value.toFixed(1)} ${units[unit]}`
}
