import type { Attribute } from '@tiptap/core'

export const MIN_WIDTH_PERCENT = 25

export const WIDTH_PERCENT_STOPS: readonly number[] = [25, 50, 75, 100]

const SNAP_TOLERANCE = 3

export function clampWidthPercent(value: number): number {
  return Math.min(100, Math.max(MIN_WIDTH_PERCENT, Math.round(value)))
}

export function snapWidthPercent(value: number): number {
  const clamped = clampWidthPercent(value)
  const hit = WIDTH_PERCENT_STOPS.find((stop) => Math.abs(clamped - stop) <= SNAP_TOLERANCE)
  return hit ?? clamped
}

export const widthPercentAttribute: Partial<Attribute> = {
  default: null,
  parseHTML: (el) => {
    const raw = el.getAttribute('data-width-percent')
    if (raw === null) return null
    const n = Number(raw)
    return Number.isFinite(n) ? clampWidthPercent(n) : null
  },
  renderHTML: (attrs) => {
    const v = attrs.widthPercent
    if (typeof v !== 'number') return {}
    return { 'data-width-percent': String(v), style: `max-width: ${v}%` }
  },
}
