import type { Editor } from '@tiptap/core'
import { post } from '@/core/bridge/post'

export function interceptLinkClick(editor: Editor, e: MouseEvent): void {
  const target = e.target instanceof Element ? e.target : null
  if (!target) return
  const diary = target.closest('[data-type="diaryLink"]')
  if (diary) {
    const id = diary.getAttribute('data-id')
    if (id) {
      e.preventDefault()
      post('linkTap', { id })
    }
    return
  }
  const anchor = target.closest('a[href]')
  if (!anchor) return
  e.preventDefault()
  const href = anchor.getAttribute('href') ?? ''
  if (href && !editor.isEditable) post('urlTap', { href })
}
