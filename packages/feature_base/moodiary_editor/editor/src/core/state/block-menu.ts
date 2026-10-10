import { createStore } from '@/lib/store'

export type BlockKind = 'image' | 'video' | 'audio'

export interface BlockTarget {
  owner: symbol
  kind: BlockKind
  anchor: HTMLElement
  getPos: () => number | undefined
}

export const blockMenu = createStore<{ owner: symbol | null; previewWidth: number | null }>({
  owner: null,
  previewWidth: null,
})

let opener: ((target: BlockTarget) => void) | null = null

export function registerBlockMenu(fn: ((target: BlockTarget) => void) | null): void {
  opener = fn
}

export function openBlockMenu(target: BlockTarget): void {
  opener?.(target)
}
