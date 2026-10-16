import { useEffect, useState } from 'react'
import { cachedMedia, isLocalMedia, resolveMedia } from '@/core/editor/media'

export function useMediaSrc(name: string | null | undefined, poster = false): string | undefined {
  const local = !!name && isLocalMedia(name)
  const [url, setUrl] = useState<string | null | undefined>(() =>
    local ? cachedMedia({ name: name!, poster }) : name,
  )
  useEffect(() => {
    if (!name || !local) {
      setUrl(name)
      return
    }
    let alive = true
    void resolveMedia({ name, poster }).then((u) => {
      if (alive) setUrl(u)
    })
    return () => {
      alive = false
    }
  }, [name, local, poster])
  return url ?? undefined
}
