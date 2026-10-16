import { autoUpdate, flip, offset, shift, size, useFloating, type ReferenceType } from '@floating-ui/react-dom'

const GAP = 6
const PAD = 8

export interface HeightRange {
  min: number
  max: number
}

export function useAnchoredFloating(reference: ReferenceType | null, height?: HeightRange) {
  return useFloating({
    open: reference !== null,
    elements: { reference },
    strategy: 'fixed',
    placement: 'bottom-start',
    whileElementsMounted: autoUpdate,
    middleware: [
      offset(GAP),
      flip({ padding: PAD, crossAxis: false }),
      shift({ padding: PAD }),
      size({
        padding: PAD,
        apply: ({ availableHeight, elements }) => {
          const h = height ? Math.max(height.min, Math.min(height.max, availableHeight)) : availableHeight
          elements.floating.style.maxHeight = `${Math.round(h)}px`
        },
      }),
    ],
  })
}
