import { Extension, type Editor } from '@tiptap/core'
import { TextSelection, type Command, type EditorState } from '@tiptap/pm/state'
import {
  SearchQuery,
  findNext,
  findPrev,
  getSearchState,
  replaceAll as pmReplaceAll,
  replaceNext,
  search,
  setSearchState,
} from 'prosemirror-search'

interface SearchStatus {
  query: string
  total: number
  current: number
}

export const SearchExtension = Extension.create({
  name: 'editorSearch',
  addProseMirrorPlugins() {
    return [search()]
  },
})

function activeQuery(state: EditorState): SearchQuery | null {
  const query = getSearchState(state)?.query
  return query && query.valid ? query : null
}

export function searchStatus(state: EditorState): SearchStatus {
  const query = activeQuery(state)
  if (!query) return { query: getSearchState(state)?.query.search ?? '', total: 0, current: 0 }
  const { from, to } = state.selection
  let total = 0
  let current = 0
  let pos = 0
  for (;;) {
    const m = query.findNext(state, pos)
    if (!m) break
    total += 1
    if (m.from === from && m.to === to) current = total
    pos = m.to > m.from ? m.to : m.to + 1
  }
  return { query: query.search, total, current }
}

function run(editor: Editor, cmd: Command): boolean {
  return cmd(editor.state, editor.view.dispatch, editor.view)
}

function setQuery(editor: Editor, query: SearchQuery): void {
  editor.view.dispatch(setSearchState(editor.state.tr, query))
}

// 从 selection.from 起找：逐字搜索时当前项不往后跳
export function startSearch(editor: Editor, text: string, caseSensitive = false): void {
  setQuery(editor, new SearchQuery({ search: text, caseSensitive, literal: true }))
  const query = activeQuery(editor.state)
  if (!query) return
  const { state } = editor
  const hit = query.findNext(state, state.selection.from) ?? query.findNext(state, 0)
  if (!hit) return
  editor.view.dispatch(
    state.tr.setSelection(TextSelection.create(state.doc, hit.from, hit.to)).scrollIntoView(),
  )
}

export function searchNext(editor: Editor): void {
  run(editor, findNext)
}

export function searchPrev(editor: Editor): void {
  run(editor, findPrev)
}

function withReplace(editor: Editor, text: string): SearchQuery | null {
  const current = getSearchState(editor.state)?.query
  if (!current || !current.valid) return null
  const next = new SearchQuery({
    search: current.search,
    caseSensitive: current.caseSensitive,
    literal: current.literal,
    replace: text,
  })
  setQuery(editor, next)
  return next
}

export function replaceCurrent(editor: Editor, text: string): void {
  if (withReplace(editor, text)) run(editor, replaceNext)
}

export function replaceAllMatches(editor: Editor, text: string): void {
  if (withReplace(editor, text)) run(editor, pmReplaceAll)
}

export function clearSearch(editor: Editor): void {
  setQuery(editor, new SearchQuery({ search: '' }))
}
