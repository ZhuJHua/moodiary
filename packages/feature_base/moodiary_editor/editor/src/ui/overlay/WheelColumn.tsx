import { useImperativeHandle, useRef, type Ref } from 'react'

const ITEM = 40

export interface WheelColumnHandle {
  scrollTo(index: number): void
  current(): number
}

export default function WheelColumn({
  ref,
  items,
  label,
  className,
}: {
  ref?: Ref<WheelColumnHandle>
  items: string[]
  label: string
  className?: string
}) {
  const list = useRef<HTMLDivElement>(null)

  useImperativeHandle(
    ref,
    () => ({
      scrollTo: (index) => {
        if (list.current) list.current.scrollTop = index * ITEM
      },
      current: () => {
        const top = list.current?.scrollTop ?? 0
        return Math.min(items.length - 1, Math.max(0, Math.round(top / ITEM)))
      },
    }),
    [items.length],
  )

  return (
    <div className={`moodiary-wheel${className ? ` ${className}` : ''}`}>
      <div className="moodiary-wheel__band" aria-hidden="true"></div>
      <div ref={list} className="moodiary-wheel__list" role="listbox" aria-label={label} tabIndex={-1}>
        {items.map((item, i) => (
          <div
            key={i}
            className="moodiary-wheel__item"
            onClick={() => list.current?.scrollTo({ top: i * ITEM, behavior: 'smooth' })}
          >
            {item}
          </div>
        ))}
      </div>
    </div>
  )
}
