import { createStore } from '@/lib/store'

export type BlockKind = 'image' | 'video' | 'audio'

export interface BlockTarget {
  owner: string
  kind: BlockKind
  anchor: HTMLElement
  getPos: () => number | undefined
}

export const blockMenu = createStore<{ target: BlockTarget | null; previewWidth: number | null }>({
  target: null,
  previewWidth: null,
})

export function openBlockMenu(target: BlockTarget): void {
  blockMenu.set({ target, previewWidth: null })
}

export function closeBlockMenu(): void {
  blockMenu.patch({ target: null, previewWidth: null })
}
