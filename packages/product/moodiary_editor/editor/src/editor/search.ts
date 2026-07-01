// 编辑器内查找/替换：用官方 prosemirror-search（search 插件高亮匹配 + SearchQuery/命令）。
// 本模块产出：① SearchExtension（挂 search 插件，绑定 editor 实例）；② 响应式 editorSearch 状态 +
// 一组操作函数，供 EditorSearchBar.vue 消费。匹配高亮配色见 moodiary-editor.css 的 .ProseMirror-search-match。
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
import { reactive } from 'vue'

export const editorSearch = reactive({
  open: false,
  term: '',
  replace: '',
  caseSensitive: false,
  count: 0,
  current: 0, // 当前选中匹配的序号（1 起；0 表示选区不在任何匹配上）
})

let boundEditor: Editor | null = null

function buildQuery(): SearchQuery {
  return new SearchQuery({
    search: editorSearch.term,
    caseSensitive: editorSearch.caseSensitive,
    replace: editorSearch.replace,
  })
}

function applyQuery(): void {
  const editor = boundEditor
  if (!editor) return
  editor.view.dispatch(setSearchState(editor.state.tr, buildQuery()))
  updateCounts()
}

function updateCounts(): void {
  const editor = boundEditor
  if (!editor || !editorSearch.term) {
    editorSearch.count = 0
    editorSearch.current = 0
    return
  }
  const state = editor.state
  const ss = getSearchState(state)
  if (!ss || !ss.query.valid) {
    editorSearch.count = 0
    editorSearch.current = 0
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
  editorSearch.count = count
  editorSearch.current = current
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
  editorSearch.open = true
  // 选中一段单行文字时预填为搜索词。
  if (editor) {
    const { from, to } = editor.state.selection
    if (to > from) {
      const text = editor.state.doc.textBetween(from, to, ' ')
      if (text && !text.includes('\n')) editorSearch.term = text
    }
  }
  applyQuery()
}

export function closeSearch(): void {
  editorSearch.open = false
  const editor = boundEditor
  if (editor) {
    // 清空查询 → 撤掉高亮。
    editor.view.dispatch(setSearchState(editor.state.tr, new SearchQuery({ search: '' })))
    editor.commands.focus()
  }
}

export function setTerm(value: string): void {
  editorSearch.term = value
  applyDebounced()
}
export function setReplace(value: string): void {
  editorSearch.replace = value
}
export function toggleCase(): void {
  editorSearch.caseSensitive = !editorSearch.caseSensitive
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
  onDestroy() {
    if (boundEditor === this.editor) boundEditor = null
  },
  addProseMirrorPlugins() {
    return [search()]
  },
})
