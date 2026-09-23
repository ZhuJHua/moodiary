import { mergeAttributes } from '@tiptap/core'
import Mention from '@tiptap/extension-mention'
import type { SuggestionKeyDownProps, SuggestionProps } from '@tiptap/suggestion'
import { reactive } from 'vue'
import { post } from '../bridge/post'
import { diaryLinkMarkdownSpec } from './markdown'

export interface DiaryCandidate {
  id: string
  label: string
}

export const linkSuggestion = reactive<{
  open: boolean
  loading: boolean
  query: string
  items: DiaryCandidate[]
  index: number
  rect: { left: number; top: number; bottom: number } | null
}>({ open: false, loading: false, query: '', items: [], index: 0, rect: null })

let currentCommand: ((item: DiaryCandidate) => void) | null = null

export function selectCandidate(item: DiaryCandidate): void {
  currentCommand?.(item)
}

const resolvers = new Map<string, (list: DiaryCandidate[]) => void>()
let reqSeq = 0

function requestCandidates(query: string, signal?: AbortSignal): Promise<DiaryCandidate[]> {
  return new Promise<DiaryCandidate[]>((resolve) => {
    const reqId = `lc-${++reqSeq}`
    const finish = (list: DiaryCandidate[]): void => {
      window.clearTimeout(timer)
      signal?.removeEventListener('abort', onAbort)
      resolvers.delete(reqId)
      resolve(list)
    }
    const onAbort = (): void => finish([])
    const timer = window.setTimeout(() => finish([]), 4000)
    signal?.addEventListener('abort', onAbort, { once: true })
    resolvers.set(reqId, finish)
    post('requestLinkCandidates', { reqId, query })
  })
}

export function resolveLinkCandidates(reqId: string, json: string): void {
  const r = resolvers.get(reqId)
  if (!r) return
  let list: DiaryCandidate[] = []
  try {
    const parsed = JSON.parse(json)
    if (Array.isArray(parsed)) {
      list = parsed
        .filter((x) => x && typeof x.id === 'string')
        .map((x) => ({ id: x.id as string, label: String(x.label ?? x.id) }))
    }
  } catch {
  }
  r(list)
}

function close(): void {
  linkSuggestion.open = false
  linkSuggestion.loading = false
  linkSuggestion.items = []
  linkSuggestion.query = ''
  currentCommand = null
}

function sync(props: SuggestionProps<DiaryCandidate>): void {
  currentCommand = props.command
  const r = props.clientRect?.()
  if (r) linkSuggestion.rect = { left: r.left, top: r.top, bottom: r.bottom }
  linkSuggestion.query = props.query ?? ''
  linkSuggestion.loading = props.loading
  if (linkSuggestion.items !== props.items) {
    linkSuggestion.items = props.items
    linkSuggestion.index = 0
  }
}

function handleKey(e: KeyboardEvent): boolean {
  if (!linkSuggestion.open) return false
  if (e.key === 'Escape') {
    close()
    return true
  }
  const n = linkSuggestion.items.length
  if (n === 0) return false
  if (e.key === 'ArrowDown') {
    linkSuggestion.index = (linkSuggestion.index + 1) % n
    return true
  }
  if (e.key === 'ArrowUp') {
    linkSuggestion.index = (linkSuggestion.index - 1 + n) % n
    return true
  }
  if (e.key === 'Enter') {
    const it = linkSuggestion.items[linkSuggestion.index]
    if (it) currentCommand?.(it)
    return true
  }
  return false
}

export const DiaryLink = Mention.extend({
  name: 'diaryLink',
  addAttributes() {
    const { mentionSuggestionChar: _c, ...parent } = (this.parent?.() ?? {}) as Record<
      string,
      unknown
    >
    return parent
  },
  ...diaryLinkMarkdownSpec,
}).configure({
  HTMLAttributes: { class: 'moodiary-link' },
  deleteTriggerWithBackspace: true,
  renderHTML: ({ options, node }) => [
    'span',
    mergeAttributes(
      {
        'data-type': 'diaryLink',
        'data-id': node.attrs.id,
        'data-label': node.attrs.label,
      },
      options.HTMLAttributes,
    ),
    String(node.attrs.label ?? node.attrs.id ?? ''),
  ],
  renderText: ({ node }) => `[[${node.attrs.label ?? node.attrs.id ?? ''}]]`,
  suggestion: {
    char: '[[',
    allowSpaces: true,
    // 默认 allowedPrefixes 要求触发符前为空格/行首，这里关掉以支持任意位置触发
    allowedPrefixes: null,
    minQueryLength: 1,
    debounce: 250,
    items: ({ query, signal }) => {
      const q = query.trim()
      return q ? requestCandidates(q, signal) : Promise.resolve([])
    },
    render: () => ({
      onStart: (props: SuggestionProps<DiaryCandidate>) => {
        linkSuggestion.open = true
        sync(props)
      },
      onUpdate: (props: SuggestionProps<DiaryCandidate>) => sync(props),
      onKeyDown: (props: SuggestionKeyDownProps) => handleKey(props.event),
      onExit: () => close(),
    }),
  },
})
