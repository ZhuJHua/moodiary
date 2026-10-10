import { Extension } from '@tiptap/core'
import type { Editor } from '@tiptap/core'
import type { Command } from '@tiptap/pm/state'
import {
  SearchQuery,
  findNext,
  findPrev,
  getSearchState,
  replaceAll,
  replaceNext,
  search,
  setSearchState,
} from 'prosemirror-search'
import { createStore } from '@/lib/store'

export interface EditorSearchState {
  open: boolean
  term: string
  replace: string
  caseSensitive: boolean
  count: number
  current: number
}

export const editorSearch = createStore<EditorSearchState>({
  open: false,
  term: '',
  replace: '',
  caseSensitive: false,
  count: 0,
  current: 0,
})

let boundEditor: Editor | null = null

function buildQuery(): SearchQuery {
  const s = editorSearch.get()
  return new SearchQuery({ search: s.term, caseSensitive: s.caseSensitive, replace: s.replace })
}

function applyQuery(): void {
  const editor = boundEditor
  if (!editor) return
  editor.view.dispatch(setSearchState(editor.state.tr, buildQuery()))
  updateCounts()
}

function updateCounts(): void {
  const editor = boundEditor
  if (!editor || !editorSearch.get().term) {
    editorSearch.patch({ count: 0, current: 0 })
    return
  }
  const state = editor.state
  const ss = getSearchState(state)
  if (!ss || !ss.query.valid) {
    editorSearch.patch({ count: 0, current: 0 })
    return
  }
  const query = ss.query
  const sel = state.selection
  let count = 0
  let current = 0
  let from = 0
  let safety = 100000
  for (;;) {
    if (safety-- <= 0) break
    const m = query.findNext(state, from)
    if (!m) break
    count++
    if (m.from === sel.from && m.to === sel.to) current = count
    from = m.to > m.from ? m.to : m.to + 1 // 防零宽匹配死循环
  }
  editorSearch.patch({ count, current })
}

function runCmd(cmd: Command): void {
  const editor = boundEditor
  if (!editor) return
  cmd(editor.state, editor.view.dispatch, editor.view)
  updateCounts()
}

let debounce = 0
function applyDebounced(): void {
  window.clearTimeout(debounce)
  debounce = window.setTimeout(applyQuery, 150)
}

export function openSearch(): void {
  const editor = boundEditor
  const next: Partial<EditorSearchState> = { open: true }
  if (editor) {
    const { from, to } = editor.state.selection
    if (to > from) {
      const text = editor.state.doc.textBetween(from, to, ' ')
      if (text && !text.includes('\n')) next.term = text
    }
  }
  editorSearch.patch(next)
  applyQuery()
}

export function closeSearch(): void {
  editorSearch.patch({ open: false })
  const editor = boundEditor
  if (editor) {
    editor.view.dispatch(setSearchState(editor.state.tr, new SearchQuery({ search: '' })))
    editor.commands.focus()
  }
}

export function setTerm(value: string): void {
  editorSearch.patch({ term: value })
  applyDebounced()
}
export function setReplace(value: string): void {
  editorSearch.patch({ replace: value })
}
export function toggleCase(): void {
  editorSearch.patch({ caseSensitive: !editorSearch.get().caseSensitive })
  applyQuery()
}
export function nextMatch(): void {
  runCmd(findNext)
}
export function prevMatch(): void {
  runCmd(findPrev)
}
export function replaceOne(): void {
  applyQuery() // 确保 replace 文本最新
  runCmd(replaceNext)
  applyQuery()
}
export function replaceAllMatches(): void {
  applyQuery()
  runCmd(replaceAll)
  applyQuery()
}

export const SearchExtension = Extension.create({
  name: 'editorSearch',
  onCreate() {
    boundEditor = this.editor
  },
  onTransaction({ transaction }) {
    if (transaction.docChanged && editorSearch.get().open) updateCounts()
  },
  onDestroy() {
    if (boundEditor === this.editor) boundEditor = null
  },
  addProseMirrorPlugins() {
    return [search()]
  },
})
