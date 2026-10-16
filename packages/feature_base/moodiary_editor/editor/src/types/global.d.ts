import type { MoodiaryBridge } from '@/core/bridge'

declare global {
  interface Window {
    MoodiaryEditor?: { postMessage: (message: string) => void }
    MoodiaryBridge: MoodiaryBridge
  }
}

export {}
