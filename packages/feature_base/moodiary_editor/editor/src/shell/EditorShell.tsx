import { useEffect, useRef } from 'react'
import { boundApi } from '@/core/bridge'
import { post } from '@/core/bridge/post'
import { dismissKeyboard } from '@/core/editor/keyboard'
import { unproxyMedia } from '@/core/editor/media'
import { editable as editableStore } from '@/core/state/editable'
import { useStore } from '@/lib/store'
import BlockMenu from '@/ui/block/BlockMenu'
import DiaryLinkSuggestion from '@/ui/DiaryLinkSuggestion'
import EditorSearchBar from '@/ui/EditorSearchBar'
import EditorViewport from '@/ui/EditorViewport'
import { useDiaryEditor } from '@/ui/hooks/use-diary-editor'
import { useFindShortcut } from '@/ui/hooks/use-find-shortcut'
import { useKeepCaretVisible } from '@/ui/hooks/use-keep-caret-visible'
import UndoToast from '@/ui/overlay/UndoToast'
import EditorToolbar, { type PickType } from '@/ui/toolbar/EditorToolbar'

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
    if (!editableStore.get() && /^https?:\/\//i.test(url)) post('urlTap', { url })
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

function pick(type: PickType): void {
  dismissKeyboard()
  post(type)
}

export default function EditorShell() {
  const shell = useRef<HTMLDivElement>(null)
  const editor = useDiaryEditor()
  const editable = useStore(editableStore)
  useKeepCaretVisible(editor)
  useFindShortcut()
  useEffect(() => {
    const el = shell.current
    el?.addEventListener('click', onClick)
    return () => el?.removeEventListener('click', onClick)
  }, [])

  return (
    <div ref={shell} className="editor-shell">
      <div className="moodiary-editor-root">
        <EditorViewport editor={editor} />
        <EditorSearchBar />
        <UndoToast />
        {editable && <EditorToolbar editor={editor} onPick={pick} />}
        {editable && <BlockMenu editor={editor} />}
      </div>
      <DiaryLinkSuggestion />
    </div>
  )
}
