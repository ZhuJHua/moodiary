import { mergeAttributes } from '@tiptap/core'
import Mention from '@tiptap/extension-mention'
import type { SuggestionKeyDownProps, SuggestionProps } from '@tiptap/suggestion'
import { reactive } from 'vue'
import { post } from '../bridge/post'

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

function requestCandidates(query: string): Promise<DiaryCandidate[]> {
  return new Promise<DiaryCandidate[]>((resolve) => {
    const reqId = `lc-${++reqSeq}`
    const timer = window.setTimeout(() => {
      if (resolvers.delete(reqId)) resolve([])
    }, 4000)
    resolvers.set(reqId, (list) => {
      window.clearTimeout(timer)
      resolve(list)
    })
    post('requestLinkCandidates', { reqId, query })
  })
}

export function resolveLinkCandidates(reqId: string, json: string): void {
  const r = resolvers.get(reqId)
  if (!r) return
  resolvers.delete(reqId)
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

let searchSeq = 0
let debounceTimer = 0

function close(): void {
  linkSuggestion.open = false
  linkSuggestion.loading = false
  linkSuggestion.items = []
  linkSuggestion.query = ''
  window.clearTimeout(debounceTimer)
  searchSeq++
  currentCommand = null
}

function setRect(props: SuggestionProps<DiaryCandidate>): void {
  const r = props.clientRect?.()
  if (r) linkSuggestion.rect = { left: r.left, top: r.top, bottom: r.bottom }
}

function runSearch(query: string): void {
  linkSuggestion.query = query
  linkSuggestion.index = 0
  window.clearTimeout(debounceTimer)
  const q = query.trim()
  if (!q) {
    searchSeq++
    linkSuggestion.loading = false
    linkSuggestion.items = []
    return
  }
  linkSuggestion.loading = true
  const seq = ++searchSeq
  debounceTimer = window.setTimeout(() => {
    requestCandidates(q).then((list) => {
      if (seq !== searchSeq) return
      linkSuggestion.items = list
      linkSuggestion.index = 0
      linkSuggestion.loading = false
    })
  }, 250)
}

function handleStart(props: SuggestionProps<DiaryCandidate>): void {
  linkSuggestion.open = true
  currentCommand = props.command
  setRect(props)
  runSearch(props.query ?? '')
}

function handleUpdate(props: SuggestionProps<DiaryCandidate>): void {
  currentCommand = props.command
  setRect(props)
  if ((props.query ?? '') !== linkSuggestion.query) runSearch(props.query ?? '')
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

export const DiaryLink = Mention.extend({ name: 'diaryLink' }).configure({
  HTMLAttributes: { class: 'moodiary-link' },
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
    items: () => [],
    command: ({ editor, range, props }) => {
      const item = props as unknown as DiaryCandidate
      editor
        .chain()
        .focus()
        .insertContentAt(range, [
          { type: 'diaryLink', attrs: { id: item.id, label: item.label } },
          { type: 'text', text: ' ' },
        ])
        .run()
    },
    render: () => ({
      onStart: (props: SuggestionProps<DiaryCandidate>) => handleStart(props),
      onUpdate: (props: SuggestionProps<DiaryCandidate>) => handleUpdate(props),
      onKeyDown: (props: SuggestionKeyDownProps) => handleKey(props.event),
      onExit: () => close(),
    }),
  },
})
