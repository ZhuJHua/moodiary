import { useId } from 'react'
import { blockMenu, openBlockMenu, type BlockKind } from '@/core/state/block-menu'
import { editable } from '@/core/state/editable'
import { useStore } from '@/lib/store'

export const widthPercentOf = (v: unknown): number | null => (typeof v === 'number' ? v : null)

export function useBlockMenu(
  kind: BlockKind,
  getPos: () => number | undefined,
  widthPercent: number | null = null,
): {
  canEdit: boolean
  menuOpen: boolean
  shownWidth: number | null
  openMenu: (anchor: HTMLElement) => void
} {
  const owner = useId()
  const menuOpen = useStore(blockMenu, (s) => s.target?.owner === owner)
  const previewWidth = useStore(blockMenu, (s) =>
    s.target?.owner === owner ? s.previewWidth : null,
  )
  const canEdit = useStore(editable)
  return {
    canEdit,
    menuOpen,
    shownWidth: previewWidth ?? widthPercent,
    openMenu: (anchor) => openBlockMenu({ owner, kind, anchor, getPos }),
  }
}
