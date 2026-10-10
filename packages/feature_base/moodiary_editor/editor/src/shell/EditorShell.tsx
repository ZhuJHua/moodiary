import { useEffect, useRef } from 'react'
import { boundApi } from '@/core/bridge'
import type { Platform } from '@/core/bridge/boot'
import { post } from '@/core/bridge/post'
import { unproxyMedia } from '@/core/editor/media'
import { editable } from '@/core/state/editable'
import DiaryLinkSuggestion from '@/ui/DiaryLinkSuggestion'
import { useFindShortcut } from '@/ui/hooks/use-find-shortcut'
import DesktopShell from './DesktopShell'
import MobileShell from './MobileShell'

// 原生 click 监听先于 React 合成事件，链接 preventDefault 和 BlockHandle 的 stopPropagation 都依赖这个顺序
function onClick(e: MouseEvent): void {
  const target = e.target as HTMLElement | null
  const link = target?.closest('[data-type="diaryLink"]') as HTMLElement | null
  if (link) {
    const id = link.getAttribute('data-id')
    if (id) {
      e.preventDefault()
      post('linkTap', { id })
    }
    return
  }
  const anchor = target?.closest('a[href]') as HTMLAnchorElement | null
  if (anchor && anchor.closest('.ProseMirror')) {
    e.preventDefault()
    const url = anchor.getAttribute('href') ?? ''
    if (!editable.get() && /^https?:\/\//i.test(url)) post('urlTap', { url })
    return
  }
  const img = target?.closest('img')
  if (!img) return
  const src = img.getAttribute('src')
  if (!src || src.startsWith('data:')) return
  e.preventDefault()
  const name = unproxyMedia(src)
  const api = boundApi()
  if (api) api.previewImage(name)
  else post('imageTap', { src: name, srcs: [name], index: 0 })
}

export default function EditorShell({ platform }: { platform: Platform }) {
  const shell = useRef<HTMLDivElement>(null)
  useFindShortcut()
  useEffect(() => {
    const el = shell.current
    el?.addEventListener('click', onClick)
    return () => el?.removeEventListener('click', onClick)
  }, [])
  return (
    <div ref={shell} className="editor-shell">
      {platform === 'mobile' ? <MobileShell /> : <DesktopShell />}
      <DiaryLinkSuggestion />
    </div>
  )
}
