import { useEffect, useRef } from 'react'
import MoodiaryEditor from './EditorFrame'
import DiaryLinkSuggestion from '@/ui/DiaryLinkSuggestion'
import { boundApi, installBridge } from '@/core/bridge'
import { readBoot } from '@/core/bridge/boot'
import { applyTheme, setFontBase } from '@/core/bridge/theme'
import { post } from '@/core/bridge/post'
import { editable } from '@/core/state/editable'
import { setMediaInfoPrefix, setMediaPrefix, unproxyMedia } from '@/core/editor/media'

const boot = readBoot()
if (boot.mediaBase) setMediaPrefix(boot.mediaBase)
if (boot.mediaInfoBase) setMediaInfoPrefix(boot.mediaInfoBase)
// 字体文件基址须先于 applyTheme 注入：applyTheme 里用它拼 @font-face 的 src。
if (boot.fontBase) setFontBase(boot.fontBase)
const initialEditable = boot.editable ?? true
const platform = boot.platform ?? 'desktop'

installBridge()
if (boot.theme) applyTheme(boot.theme)

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

export default function App() {
  const shell = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const el = shell.current
    el?.addEventListener('click', onClick)
    return () => el?.removeEventListener('click', onClick)
  }, [])
  return (
    <div ref={shell} className="editor-shell">
      <MoodiaryEditor editable={initialEditable} platform={platform} />
      <DiaryLinkSuggestion />
    </div>
  )
}
