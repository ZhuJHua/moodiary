import { applyTheme, type EditorTheme } from './theme'
import { post } from './post'
import { setLinks, setMeta } from './meta'
import { setSaveStatus } from './save-status'
import { getScrollY, setScrollY } from './scroll'
import { focusTitle, setTitle } from './title'
import type { EditorApi } from '../editor/tiptap'

let api: EditorApi | null = null
let ready = false

export function bindApi(value: EditorApi): void {
  api = value
}

export function markReady(): void {
  ready = true
  post('ready')
}

export function emitChange(content: string): void {
  if (ready) post('change', content)
}

export function installBridge(): void {
  window.MoodiaryBridge = {
    setContent: (content: string) => api?.setContent(content ?? ''),
    getContent: () => api?.getContent() ?? '',
    setTheme: (theme: EditorTheme) => applyTheme(theme),
    setSaveStatus: (status: string) => setSaveStatus(status),
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
    setEditable: (value: boolean) => api?.setEditable(value),
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
    getScrollY: () => getScrollY(),
    setScrollY: (y: number) => setScrollY(y),
  }
}
