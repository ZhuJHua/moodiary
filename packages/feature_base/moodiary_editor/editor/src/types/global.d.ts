import type { PageState } from '@/core/bridge'
import type { EditorBoot } from '@/core/bridge/boot'
import type { EditorTheme } from '@/core/bridge/theme'

interface JsChannel {
  postMessage: (message: string) => void
}

declare global {
  interface Window {
    MoodiaryEditor?: JsChannel
    MoodiaryBridge: {
      applyState: (state: Partial<PageState>) => void
      setContent: (content: string) => void
      getContent: () => string
      setTheme: (theme: EditorTheme) => void
      setTitle: (title: string) => void
      setMeta: (json: string) => void
      setLinks: (json: string) => void
      focus: () => void
      blur: () => void
      focusTitle: () => void
      setEditable: (value: boolean) => void
      reset: () => void
      insertMedia: (name: string, alt?: string) => void
      insertAudio: (name: string) => void
      insertVideo: (name: string) => void
      resolveImage: (id: string, name: string) => void
      resolveLinkCandidates: (reqId: string, json: string) => void
      scrollToHeading: (index: number) => void
      resumeVideo: (name: string, seconds: number) => void
      dismissOverlay: () => void
      getScrollY: () => number
      setScrollY: (y: number) => void
    }
    __BOOT__?: EditorBoot
  }
}

export {}
