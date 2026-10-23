import type { Node as PMNode } from '@tiptap/pm/model'

// 与 Dart MediaMarkup 同一格式：U+FDD1 起按类型排的开始符 + 名称 + U+FDD0，U+FDD0–FDEF 不许出现在用户文字里
const CLOSE = '\uFDD0'
const OPEN: Record<string, string> = { image: '\uFDD1', video: '\uFDD2', audio: '\uFDD3', attachment: '\uFDD4' }
const RESERVED = /[\uFDD0-\uFDEF]/g
const MEDIA_RUN = /[\uFDD1-\uFDEF][^\uFDD0-\uFDEF]*\uFDD0?/g

const strip = (text: string): string => text.replace(RESERVED, '')

function mediaName(node: PMNode): string {
  const name = node.attrs.name
  return typeof name === 'string' ? strip(name).replace(/\s*[\r\n]+\s*/g, ' ').replace(/^\s+|\s+$/g, '') : ''
}

function leafText(node: PMNode): string {
  const open = OPEN[node.type.name]
  if (open) {
    const name = mediaName(node)
    return name ? open + name + CLOSE : ''
  }
  switch (node.type.name) {
    case 'hardBreak':
      return '\n'
    case 'diaryLink':
      return strip(String(node.attrs.label || node.attrs.id || ''))
    default:
      return ''
  }
}

// 与 Dart contentText 同一契约：照 PM textBetween(0, size, '\n') 走，只多了剔除保留字符
export function plainTextOf(doc: PMNode): string {
  let text = ''
  let first = true
  doc.nodesBetween(0, doc.content.size, (node) => {
    const nodeText = node.isText ? strip(node.text ?? '') : node.isLeaf ? leafText(node) : ''
    if (node.isBlock && ((node.isLeaf && nodeText) || node.isTextblock)) {
      if (first) first = false
      else text += '\n'
    }
    text += nodeText
  })
  return text
}

export const bodyTextOf = (text: string): string => text.replace(MEDIA_RUN, '').replace(RESERVED, '')

const segmenter = 'Segmenter' in Intl ? new Intl.Segmenter(undefined, { granularity: 'grapheme' }) : null

export function countCharacters(text: string): number {
  const compact = bodyTextOf(text).replace(/\s+/g, '')
  if (!segmenter) return Array.from(compact).length
  let n = 0
  for (const _ of segmenter.segment(compact)) n += 1
  return n
}
