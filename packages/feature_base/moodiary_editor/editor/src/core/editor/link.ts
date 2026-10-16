import { getMarkRange } from '@tiptap/core'
import type { EditorState } from '@tiptap/pm/state'

interface LinkAt {
  href: string
  from: number
  to: number
}

// 光标贴着链接的两端也算在链接里：iOS 点按会把光标吸到词边界，正好落在链接末尾
export function linkAt(state: EditorState): LinkAt | null {
  const type = state.schema.marks.link
  const { selection } = state
  const range = getMarkRange(selection.$from, type)
  if (!range || selection.from < range.from || selection.to > range.to) return null
  const mark = state.doc
    .nodeAt(range.from)
    ?.marks.find((m) => m.type === type)
  return mark ? { href: String(mark.attrs.href ?? ''), from: range.from, to: range.to } : null
}
