import type { EditorBoot } from '../bridge/boot'
import type { EditorTheme } from '../bridge/theme'

interface JsChannel {
  postMessage: (message: string) => void
}

declare global {
  interface Window {
    MoodiaryEditor?: JsChannel
    MoodiaryBridge: {
      setContent: (content: string) => void
      getContent: () => string
      setTheme: (theme: EditorTheme) => void
      setSaveStatus: (status: string) => void
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
      getScrollY: () => number
      setScrollY: (y: number) => void
    }
    __BOOT__?: EditorBoot
  }
}

export {}
