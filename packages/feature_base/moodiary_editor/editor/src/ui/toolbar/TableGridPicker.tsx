import { useState } from 'react'
import { cn } from 'cn'
import { keepFocus } from '@/lib/utils'

const MAX_R = 8
const MAX_C = 8
const ROWS = Array.from({ length: MAX_R }, (_, i) => i + 1)
const COLS = Array.from({ length: MAX_C }, (_, i) => i + 1)

export default function TableGridPicker({ onSelect }: { onSelect: (rows: number, cols: number) => void }) {
  const [hr, setHr] = useState(1)
  const [hc, setHc] = useState(1)

  return (
    <div className="p-2">
      <div className="grid w-max gap-0.5" style={{ gridTemplateColumns: `repeat(${MAX_C}, 1.25rem)` }}>
        {ROWS.map((r) =>
          COLS.map((c) => (
            <button
              key={`${r}-${c}`}
              type="button"
              className={cn(
                'size-5 rounded-[3px] border',
                r <= hr && c <= hc ? 'border-primary bg-primary/40' : 'border-border',
              )}
              onMouseEnter={() => {
                setHr(r)
                setHc(c)
              }}
              onMouseDown={keepFocus}
              onClick={() => onSelect(r, c)}
            />
          )),
        )}
      </div>
      <div className="mt-1.5 text-center text-xs text-muted-foreground tabular-nums">
        {hc} × {hr}
      </div>
    </div>
  )
}
