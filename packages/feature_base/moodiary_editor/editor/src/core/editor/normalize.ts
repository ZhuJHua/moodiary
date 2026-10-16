import type { JSONContent } from '@tiptap/core'

export const SCHEMA_VERSION = 2

const WIDTH_PERCENT_STOPS = [25, 50, 75, 100] as const

export type HorizontalRuleVariant = 'solid' | 'dashed' | 'dotted' | 'double' | 'wavy' | 'text'

export const HR_VARIANTS: readonly HorizontalRuleVariant[] = [
  'solid',
  'dashed',
  'dotted',
  'double',
  'wavy',
  'text',
]

export function snapWidthPercent(value: unknown): number | null {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null
  const clamped = Math.min(100, Math.max(25, Math.round(value)))
  let best: number = WIDTH_PERCENT_STOPS[0]
  for (const stop of WIDTH_PERCENT_STOPS) {
    if (Math.abs(clamped - stop) < Math.abs(clamped - best)) best = stop
  }
  return best
}

type Attrs = Record<string, unknown>

const nonEmpty = (v: unknown): string | null => (typeof v === 'string' && v ? v : null)

function normalizeMarks(marks: JSONContent['marks']): JSONContent['marks'] {
  if (!marks) return marks
  return marks.map((mark) =>
    mark.type === 'link' ? { ...mark, attrs: { href: mark.attrs?.href ?? null } } : mark,
  )
}

function normalizeAttrs(type: string | undefined, raw: Attrs | undefined): Attrs | undefined {
  switch (type) {
    case 'audio':
    case 'video': {
      if (!raw) return raw
      const { filename, ...rest } = raw
      if (rest.src == null && typeof filename === 'string') rest.src = filename
      return rest
    }
    case 'image': {
      if (!raw) return raw
      const { width: _w, height: _h, alt, title, ...rest } = raw
      if ('widthPercent' in rest) rest.widthPercent = snapWidthPercent(rest.widthPercent)
      rest.name ??= nonEmpty(alt) ?? nonEmpty(title)
      return rest
    }
    case 'diaryLink': {
      if (!raw) return raw
      const { mentionSuggestionChar: _c, ...rest } = raw
      return rest
    }
    case 'horizontalRule':
      return {
        ...raw,
        variant: (raw?.variant as string | undefined) ?? 'solid',
        label: (raw?.label as string | undefined) ?? null,
      }
    default:
      return raw
  }
}

function normalizeNode(node: JSONContent): JSONContent {
  const out: JSONContent = { ...node }
  const attrs = normalizeAttrs(node.type, node.attrs)
  if (attrs !== undefined) out.attrs = attrs
  if (node.marks) out.marks = normalizeMarks(node.marks)
  if (node.content) out.content = node.content.map(normalizeNode)
  return out
}

export function normalizeDoc(doc: JSONContent): JSONContent {
  const out = normalizeNode(doc)
  out.attrs = { ...doc.attrs, v: SCHEMA_VERSION }
  return out
}

export function docVersion(doc: JSONContent): number {
  const v = doc.attrs?.v
  return typeof v === 'number' ? v : 1
}
