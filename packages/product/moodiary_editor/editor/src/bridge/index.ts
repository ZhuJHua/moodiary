// JS 侧桥接：安装 `window.MoodiaryBridge`（Flutter → JS 命令式入口）转发到 [EditorApi]，
// 并提供 `markReady` / `emitChange`（JS → Flutter 事件）。就绪前各方法 no-op，Flutter 可安全调用。

import { applyTheme, type SeedTheme } from './theme'
import { post } from './post'
import { setSaveStatus } from './save-status'
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

/** 编辑器内容变化上报（TipTap 文档 JSON 串）；就绪前（含初始内容解析阶段）不上报，避免回弹初始值。 */
export function emitChange(content: string): void {
  if (ready) post('change', content)
}

export function installBridge(): void {
  window.MoodiaryBridge = {
    setContent: (content: string) => api?.setContent(content ?? ''),
    getContent: () => api?.getContent() ?? '',
    setTheme: (theme: SeedTheme) => applyTheme(theme),
    setSaveStatus: (status: string) => setSaveStatus(status),
    focus: () => api?.focus(),
    setEditable: (value: boolean) => api?.setEditable(value),
    reset: () => api?.reset(),
    insertMedia: (name: string, alt?: string) => api?.insertMedia(name, alt),
    insertAudio: (name: string) => api?.insertAudio(name),
    insertVideo: (name: string) => api?.insertVideo(name),
    // 拖拽/粘贴上传：Flutter 存盘后回传文件名，兑现 onUpload 的 Promise。
    resolveImage: (id: string, name: string) => api?.resolveUpload(id, name),
    // `[[` 双链：Flutter 回传候选日记列表（JSON 串），兑现 ensureCandidates 的 Promise。
    resolveLinkCandidates: (reqId: string, json: string) =>
      api?.resolveLinkCandidates(reqId, json),
  }
}
