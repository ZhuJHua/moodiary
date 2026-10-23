import { mergeAttributes, type JSONContent, type MarkdownToken } from '@tiptap/core'
import Mention from '@tiptap/extension-mention'
import type { ResolvedPos } from '@tiptap/pm/model'
import type { SuggestionKeyDownProps, SuggestionMatch, SuggestionProps } from '@tiptap/suggestion'
import { post } from '@/core/bridge/post'
import { createStore } from 'zustand/vanilla'

interface DiaryCandidate {
  id: string
  label: string
}

interface CaretReference {
  getBoundingClientRect(): DOMRect
  contextElement?: Element
}

interface LinkSuggestionState {
  open: boolean
  loading: boolean
  query: string
  items: DiaryCandidate[]
  index: number
  reference: CaretReference | null
}

export const linkSuggestionStore = createStore<LinkSuggestionState>()(() => ({
  open: false,
  loading: false,
  query: '',
  items: [],
  index: 0,
  reference: null,
}))

const DIARY_LINK_TRIGGERS = ['[[', '【【', '「「'] as const
const MAX_QUERY = 40

function findDiaryLinkMatch({ $position }: { $position: ResolvedPos }): SuggestionMatch {
  const before = $position.nodeBefore
  if (!before?.isText || !before.text) return null
  const text = before.text
  let at = -1
  let trigger = ''
  for (const t of DIARY_LINK_TRIGGERS) {
    const i = text.lastIndexOf(t)
    if (i > at) {
      at = i
      trigger = t
    }
  }
  if (at < 0) return null
  const query = text.slice(at + trigger.length)
  if (query.length > MAX_QUERY || /[\]】」\n]/.test(query)) return null
  const from = $position.pos - text.length + at
  return { range: { from, to: $position.pos }, query, text: trigger + query }
}

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
  resolvers.get(reqId)?.(JSON.parse(json) as DiaryCandidate[])
}

export function dismissSuggestion(): void {
  linkSuggestionStore.setState({ open: false, loading: false, items: [], query: '' })
  currentCommand = null
}

function sync(props: SuggestionProps<DiaryCandidate>): void {
  currentCommand = props.command
  const r = props.clientRect?.()
  const next: Partial<LinkSuggestionState> = {
    query: props.query ?? '',
    loading: props.loading,
  }
  if (r) {
    next.reference = {
      getBoundingClientRect: () => props.clientRect?.() ?? r,
      contextElement: props.editor.view.dom,
    }
  }
  if (linkSuggestionStore.getState().items !== props.items) {
    next.items = props.items
    next.index = 0
  }
  linkSuggestionStore.setState(next)
}

function handleKey(e: KeyboardEvent): boolean {
  const s = linkSuggestionStore.getState()
  if (!s.open) return false
  if (e.key === 'Escape') {
    dismissSuggestion()
    return true
  }
  const n = s.items.length
  if (n === 0) return false
  if (e.key === 'ArrowDown') {
    linkSuggestionStore.setState({ index: (s.index + 1) % n })
    return true
  }
  if (e.key === 'ArrowUp') {
    linkSuggestionStore.setState({ index: (s.index - 1 + n) % n })
    return true
  }
  if (e.key === 'Enter') {
    const it = s.items[s.index]
    if (it) currentCommand?.(it)
    return true
  }
  return false
}

const DIARY_LINK_SCHEME = 'moodiary://diary/'
const diaryLinkPattern = /^\[\[((?:\\.|[^\]\\\n])+)\]\]\(moodiary:\/\/diary\/([^)\s]+)\)/
const escapeLabel = (label: string): string => label.replace(/[\\[\]]/g, (c) => `\\${c}`)
const unescapeLabel = (label: string): string => label.replace(/\\(.)/g, '$1')

export const DiaryLink = Mention.extend({
  name: 'diaryLink',

  addAttributes() {
    const { mentionSuggestionChar: _c, ...parent } = (this.parent?.() ?? {}) as Record<string, unknown>
    return parent
  },

  markdownTokenName: 'diaryLink',
  markdownTokenizer: {
    name: 'diaryLink',
    level: 'inline',
    start: (src: string) => src.indexOf('[['),
    tokenize: (src: string) => {
      const match = diaryLinkPattern.exec(src)
      if (!match) return undefined
      return { type: 'diaryLink', raw: match[0], label: unescapeLabel(match[1]), id: match[2] }
    },
  },
  parseMarkdown: (token: MarkdownToken) => ({
    type: 'diaryLink',
    attrs: { id: token.id ?? null, label: token.label ?? null },
  }),
  renderMarkdown: (node: JSONContent) => {
    const label = escapeLabel(String(node.attrs?.label || node.attrs?.id || ''))
    const id = node.attrs?.id
    return id ? `[[${label}]](${DIARY_LINK_SCHEME}${id})` : `[[${label}]]`
  },
}).configure({
  HTMLAttributes: { class: 'md-diary-link' },
  deleteTriggerWithBackspace: true,
  renderHTML: ({ options, node }) => [
    'span',
    mergeAttributes(
      { 'data-type': 'diaryLink', 'data-id': node.attrs.id, 'data-label': node.attrs.label },
      options.HTMLAttributes,
    ),
    String(node.attrs.label || node.attrs.id || ''),
  ],
  renderText: ({ node }) => String(node.attrs.label || node.attrs.id || ''),
  suggestion: {
    char: '[[',
    allowSpaces: true,
    allowedPrefixes: null,
    findSuggestionMatch: findDiaryLinkMatch,
    debounce: 200,
    items: ({ query, signal }) => requestCandidates(query.trim(), signal),
    render: () => ({
      onStart: (props: SuggestionProps<DiaryCandidate>) => {
        linkSuggestionStore.setState({ open: true })
        sync(props)
      },
      onUpdate: (props: SuggestionProps<DiaryCandidate>) => sync(props),
      onKeyDown: (props: SuggestionKeyDownProps) => handleKey(props.event),
      onExit: dismissSuggestion,
    }),
  },
})
