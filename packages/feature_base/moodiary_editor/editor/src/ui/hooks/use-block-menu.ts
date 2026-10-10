import { useId, type CSSProperties } from 'react'
import { editable } from '@/core/state/editable'
import { useStore } from '@/lib/store'
import { blockMenu, openBlockMenu, type BlockKind } from '@/ui/block/block-menu'

export const widthPercentOf = (v: unknown): number | null => (typeof v === 'number' ? v : null)

export function useBlockMenu(
  kind: BlockKind,
  getPos: () => number | undefined,
  selected: boolean,
  widthPercent: number | null = null,
): {
  canEdit: boolean
  wrapperClass: (base: string) => string
  widthStyle: CSSProperties | undefined
  openMenu: (anchor: HTMLElement) => void
} {
  const owner = useId()
  const menuOpen = useStore(blockMenu, (s) => s.target?.owner === owner)
  const previewWidth = useStore(blockMenu, (s) =>
    s.target?.owner === owner ? s.previewWidth : null,
  )
  const canEdit = useStore(editable)
  const shown = previewWidth ?? widthPercent
  return {
    canEdit,
    wrapperClass: (base) => `${base}${selected ? ' is-selected' : ''}${menuOpen ? ' is-menu-open' : ''}`,
    widthStyle: shown === null ? undefined : { maxWidth: `${shown}%` },
    openMenu: (anchor) => openBlockMenu({ owner, kind, anchor, getPos }),
  }
}
