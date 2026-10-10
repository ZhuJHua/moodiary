import { applyTheme, type EditorTheme } from './theme'
import { post } from './post'
import { setLinks, setMeta } from '@/core/state/meta'
import { editable } from '@/core/state/editable'
import { getScrollY, setScrollY } from './scroll'
import { focusTitle, setTitle } from '@/core/state/title'
import type { EditorApi } from '@/core/editor/tiptap'
import { dismissOverlay } from '@/core/state/overlay'

export interface PageState {
  content: string
  title: string
  editable: boolean
  theme: EditorTheme
  meta: string
  links: string
}

let api: EditorApi | null = null
let ready = false

export function bindApi(value: EditorApi): void {
  api = value
}

export function boundApi(): EditorApi | null {
  return api
}

export function markReady(): void {
  if (ready) return
  ready = true
  post('ready')
}

export function emitChange(content: string): void {
  if (ready) post('change', content)
}

function setEditable(value: boolean): void {
  editable.set(value)
  api?.setEditable(value)
}

// 走 api 的调用须在页面 post('ready') 之后，Flutter 侧以此为准
export function installBridge(): void {
  window.MoodiaryBridge = {
    applyState: (s: Partial<PageState>) => {
      if (s.content !== undefined) api?.setContent(s.content)
      if (s.title !== undefined) setTitle(s.title)
      if (s.editable !== undefined) setEditable(s.editable)
      if (s.theme) applyTheme(s.theme)
      if (s.meta !== undefined) setMeta(s.meta)
      if (s.links !== undefined) setLinks(s.links)
    },
    setContent: (content: string) => api?.setContent(content ?? ''),
    getContent: () => api?.getContent() ?? '',
    setTheme: (theme: EditorTheme) => applyTheme(theme),
    setTitle: (t: string) => setTitle(t ?? ''),
    setMeta: (json: string) => setMeta(json ?? ''),
    setLinks: (json: string) => setLinks(json ?? ''),
    focus: () => api?.focus(),
    blur: () => {
      api?.blur()
      const el = document.activeElement
      if (el instanceof HTMLElement) el.blur()
    },
    focusTitle: () => focusTitle(),
    setEditable,
    reset: () => api?.reset(),
    insertMedia: (name: string, alt?: string) => api?.insertMedia(name, alt),
    insertAudio: (name: string) => api?.insertAudio(name),
    insertVideo: (name: string) => api?.insertVideo(name),
    resolveImage: (id: string, name: string) => api?.resolveUpload(id, name),
    resolveLinkCandidates: (reqId: string, json: string) =>
      api?.resolveLinkCandidates(reqId, json),
    scrollToHeading: (index: number) => api?.scrollToHeading(index),
    resumeVideo: (name: string, seconds: number) =>
      api?.resumeVideo(name ?? '', Number(seconds) || 0),
    dismissOverlay: () => dismissOverlay(),
    getScrollY: () => getScrollY(),
    setScrollY: (y: number) => setScrollY(y),
  }
}
