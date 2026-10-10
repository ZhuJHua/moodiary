import { useRef, type ComponentType, type ReactNode } from 'react'
import { Check } from 'lucide-react'
import Popover, { type PopoverHandle } from './Popover'

export interface PopupMenuItem {
  key: string
  label: string
  icon?: ComponentType<{ className?: string }>
  active: boolean
  destructive?: boolean
}

export default function PopupMenu({
  items = [],
  onSelect,
  children,
}: {
  items?: PopupMenuItem[]
  onSelect: (key: string) => void
  children?: ReactNode
}) {
  const pop = useRef<PopoverHandle>(null)
  const hasIcon = items.some((item) => item.icon != null)
  const hasActive = items.some((item) => item.active)

  return (
    <div>
      <div onClick={(e) => pop.current?.open(e.currentTarget)}>{children}</div>
      <Popover ref={pop} keepFocus panelClass="min-w-42 max-w-80">
        {items.map((item) => {
          const Icon = item.icon
          return (
            <button
              key={item.key}
              type="button"
              className={`moodiary-pop-item${item.active ? ' is-active' : ''}${item.destructive ? ' is-danger' : ''}`}
              onClick={(e) => {
                e.stopPropagation()
                onSelect(item.key)
                pop.current?.close()
              }}
            >
              {hasIcon && (
                <span className="flex w-5 shrink-0 justify-center">
                  {Icon && <Icon className="size-[19px]" />}
                </span>
              )}
              <span className="flex-1 whitespace-nowrap">{item.label}</span>
              {hasActive && (
                <span className="flex w-[18px] shrink-0 justify-center">
                  {item.active && <Check className="size-[18px]" />}
                </span>
              )}
            </button>
          )
        })}
      </Popover>
    </div>
  )
}
