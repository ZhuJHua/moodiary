import type { EditorApi } from '@/core/editor/kit'
import { resolveLinkCandidates } from '@/core/editor/nodes/diary-link'
import { modeStore } from '@/core/state/editable'
import { setLinks, setMeta } from '@/core/state/meta'
import { focusTitle, setTitle } from '@/core/state/title'
import { flushChange } from './change'
import { post } from './post'
import { respond } from './request'
import { getScrollY, setScrollY } from './scroll'
import { applyTheme } from './theme'

let api: EditorApi | null = null
let ready = false

export function bindApi(value: EditorApi | null): void {
  api = value
}

export function isReady(): boolean {
  return ready
}

export function markReady(): void {
  if (ready) return
  ready = true
  post('ready')
  const state = api?.currentState()
  if (state) post('state', state)
}

export function resetBridgeForTest(): void {
  api = null
  ready = false
}

const bridge = {
  respond,
  setContent: (content: string) => api?.setContent(content),
  setTitle,
  setEditable: (value: boolean) => {
    modeStore.setState({ editable: value })
    api?.setEditable(value)
  },
  setMeta,
  setLinks,
  setTheme: applyTheme,
  focus: () => api?.focus(),
  blur: () => {
    api?.blur()
    const el = document.activeElement
    if (el instanceof HTMLElement) el.blur()
  },
  focusTitle,
  holdSelection: () => api?.holdSelection(),
  resolveImage: (id: string, name: string) => api?.resolveUpload(id, name),
  resolveLinkCandidates,
  scrollToHeading: (index: number) => api?.scrollToHeading(index),
  getScrollY,
  setScrollY,
  resumeVideo: (name: string, seconds: number) => api?.resumeVideo(name, seconds),
  setPanelMode: (on: boolean) => modeStore.setState({ panelMode: on }),
  // 回执排在 change 之后发出，Flutter 收到它时最后一次 change 已处理完
  flush: (reqId?: string) => {
    flushChange()
    if (reqId) post('flushed', { reqId })
  },
  exec: (command: string, args?: Record<string, unknown>) => api?.exec(command, args),
}

export type MoodiaryBridge = typeof bridge

export function installBridge(): void {
  window.MoodiaryBridge = bridge
}
