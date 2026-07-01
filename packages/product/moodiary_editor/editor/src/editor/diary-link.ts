// 双链「正向链接」：基于 @tiptap/extension-mention 的 inline 节点 diaryLink（attrs {id,label}，id =
// 目标日记的业务 uuid）。输入 `[[` 触发 suggestion → 候选来自 Flutter（DiaryRepository）→ 选中插入
// 链接 chip。点击 chip 由 App.vue 的全局 click 监听发 'linkTap' 给 Flutter 跳转。
//
// 候选 = 搜索：`[[` 即弹面板（空查询提示输入）；输入后 250ms 防抖 + loading 态向 Flutter 发
// 'requestLinkCandidates{reqId,query}'，Flutter 用搜索引擎按相关性返回（限量），经
// window.MoodiaryBridge.resolveLinkCandidates(reqId, json) 回传。面板内容（loading / 提示 / 结果 / 无匹配）
// 与搜索解耦——suggestion 的 render 只驱动 open/query/rect，搜索由本模块防抖执行写入 linkSuggestion。
import { mergeAttributes } from '@tiptap/core'
import Mention from '@tiptap/extension-mention'
import type { SuggestionKeyDownProps, SuggestionProps } from '@tiptap/suggestion'
import { reactive } from 'vue'
import { post } from '../bridge/post'

export interface DiaryCandidate {
  id: string
  label: string
}

/** suggestion 弹层状态（DiaryLinkSuggestion.vue 消费）。 */
export const linkSuggestion = reactive<{
  open: boolean
  loading: boolean
  query: string
  items: DiaryCandidate[]
  index: number
  rect: { left: number; top: number; bottom: number } | null
}>({ open: false, loading: false, query: '', items: [], index: 0, rect: null })

let currentCommand: ((item: DiaryCandidate) => void) | null = null

/** 由弹层组件点击/回车时调用，触发 suggestion 插入选中项。 */
export function selectCandidate(item: DiaryCandidate): void {
  currentCommand?.(item)
}

// —— 候选 = 按 query 的搜索请求-回传（每次输入都查 Flutter 搜索引擎，不缓存全量）。—— //
const resolvers = new Map<string, (list: DiaryCandidate[]) => void>()
let reqSeq = 0

function requestCandidates(query: string): Promise<DiaryCandidate[]> {
  return new Promise<DiaryCandidate[]>((resolve) => {
    const reqId = `lc-${++reqSeq}`
    // 超时兜底：Flutter 不回则解析为空，避免补全 Promise 永挂。
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

/** Flutter 经 bridge 回传某次查询的候选（EditorApi.resolveLinkCandidates 调用）。 */
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
    /* 容错：空列表 */
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
  searchSeq++ // 取消在途搜索
  currentCommand = null
}

function setRect(props: SuggestionProps<DiaryCandidate>): void {
  const r = props.clientRect?.()
  if (r) linkSuggestion.rect = { left: r.left, top: r.top, bottom: r.bottom }
}

// 防抖搜索：空查询只弹面板提示、不搜；非空 250ms 防抖后查 Flutter，期间面板 loading。
// searchSeq 守卫：仅最新一次查询的结果生效（防乱序 / 取消）。
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
      if (seq !== searchSeq) return // 已被更新的查询取代，丢弃
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
  if (n === 0) return false // 加载中 / 无结果：方向键、回车不拦截
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
  // chip DOM：<span data-type=diaryLink data-id data-label class=moodiary-link>label</span>（点击读 data-id）。
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
  // 纯文本/复制形态：[[标签]]。
  renderText: ({ node }) => `[[${node.attrs.label ?? node.attrs.id ?? ''}]]`,
  suggestion: {
    char: '[[',
    allowSpaces: true,
    // 默认 allowedPrefixes:[' ']（触发字符前须为空格/行首），会导致「文字[[」不触发——
    // 双链要像 wiki 链接那样任意位置可触发，故关掉前缀限制。
    allowedPrefixes: null,
    // suggestion 自身的 items 不用于面板内容（内容由 runSearch 防抖搜索写入 linkSuggestion）；
    // 返回空即可，面板的开/关与渲染全由 render 回调驱动。
    items: () => [],
    command: ({ editor, range, props }) => {
      // 把 `[[query` 区间替换为链接节点 + 一个空格。
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
