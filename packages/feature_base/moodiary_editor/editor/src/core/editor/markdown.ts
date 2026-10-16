import { Markdown } from '@tiptap/markdown'
import { Marked } from 'marked'
import markedCjkFriendly from 'marked-cjk-friendly'

// 每个编辑器一份 marked 实例：@tiptap/markdown 往实例上注册 tokenizer，共用会越注册越多
export function createMarkdownExtension() {
  const marked = new Marked(markedCjkFriendly())
  return Markdown.configure({
    marked: marked as unknown as NonNullable<Parameters<typeof Markdown.configure>[0]>['marked'],
    markedOptions: { gfm: true, breaks: true },
  })
}

const BLOCK_MARKERS = [
  /^#{1,6}\s+\S/,
  /^\s{0,3}(?:[-*+]|\d+[.)])\s+\S/,
  /^\s{0,3}[-*+]\s+\[[ xX]\]\s/,
  /^\s{0,3}>\s?\S/,
  /^\s{0,3}(?:```|~~~)/,
  /^\s*\|.*\|\s*$/,
]

export function looksLikeMarkdown(text: string): boolean {
  const lines = text.replace(/\r\n?/g, '\n').split('\n')
  if (lines.filter((l) => l.trim()).length < 2) return false
  return lines.some((line) => BLOCK_MARKERS.some((re) => re.test(line)))
}
