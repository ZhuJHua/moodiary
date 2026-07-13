import type { EditorBoot } from '../bridge/boot'
import type { SeedTheme } from '../bridge/theme'

interface JsChannel {
  postMessage: (message: string) => void
}

declare global {
  interface Window {
    // JS → Flutter 事件通道。由 Flutter 的 DOCUMENT_START shim 注入（转发到 flutter_inappwebview
    // 的 callHandler，四端一致）。type 含 ready/change/error/saveImage/imageTap/pickImage/
    // pickAudio/pickVideo（音视频在 webview 内用原生 <audio>/<video> 内联播放，无 playMedia 事件）；
    // requestLinkCandidates（`[[` 双链拉候选，payload {reqId}）/ linkTap（点链接 chip，payload {id}）；
    // titleChange（顶部标题区输入，payload 为标题串）/ activeHeading（滚动时当前标题下标，payload 为 number，-1 无）。
    MoodiaryEditor?: JsChannel
    // Flutter → JS 命令式入口。content 为 TipTap 文档 JSON 串（旧 markdown 日记只读查看时也可传 md，自动识别）。
    MoodiaryBridge: {
      setContent: (content: string) => void
      getContent: () => string
      setTheme: (theme: SeedTheme) => void
      setSaveStatus: (status: string) => void
      /** 日记标题初值（打开日记时推入；用户改动经 titleChange 事件回传）。 */
      setTitle: (title: string) => void
      focus: () => void
      setEditable: (value: boolean) => void
      reset: () => void
      insertMedia: (name: string, alt?: string) => void
      insertAudio: (name: string) => void
      insertVideo: (name: string) => void
      resolveImage: (id: string, name: string) => void
      /** `[[` 双链候选回传：reqId 对应一次 requestLinkCandidates，json 为 [{id,label}] 串。 */
      resolveLinkCandidates: (reqId: string, json: string) => void
      /** 目录跳转：滚动到第 index 个 heading（文档序）。 */
      scrollToHeading: (index: number) => void
      /** 页内双链跳转的滚动位置保存 / 恢复（视口 scrollTop）。 */
      getScrollY: () => number
      setScrollY: (y: number) => void
    }
    /** 旧注入通道（DOCUMENT_START UserScript），仅作 readBoot 的兜底。 */
    __BOOT__?: EditorBoot
  }
}

export {}
