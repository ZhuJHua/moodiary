import type { Node as PMNode } from '@tiptap/pm/model'

function leafText(node: PMNode): string {
  switch (node.type.name) {
    case 'hardBreak':
      return '\n'
    case 'diaryLink':
      return String(node.attrs.label || node.attrs.id || '')
    default:
      return ''
  }
}

// 与 Dart contentText 同一契约，不裁剪、不合并空行
export function plainTextOf(doc: PMNode): string {
  return doc.textBetween(0, doc.content.size, '\n', leafText)
}

const segmenter = 'Segmenter' in Intl ? new Intl.Segmenter(undefined, { granularity: 'grapheme' }) : null

export function countCharacters(text: string): number {
  const compact = text.replace(/\s+/g, '')
  if (!segmenter) return Array.from(compact).length
  let n = 0
  for (const _ of segmenter.segment(compact)) n += 1
  return n
}
