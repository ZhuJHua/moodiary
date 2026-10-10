import type { MouseEvent } from 'react'
import { cn } from 'cn'
import { Button } from '@/ui/primitives/button'
import type { ToolIcon } from './tools'
import { keepFocus } from '@/lib/utils'

export default function ToolbarButton({
  icon: Icon,
  title,
  dense,
  active,
  disabled,
  testId,
  onClick,
}: {
  icon: ToolIcon
  title: string
  dense?: boolean
  active?: boolean
  disabled?: boolean
  testId?: string
  onClick?: (e: MouseEvent<HTMLButtonElement>) => void
}) {
  return (
    <Button
      variant="ghost"
      size={dense ? 'icon-lg' : 'icon'}
      className={cn(dense && 'size-10', active && 'bg-accent text-primary')}
      title={title}
      data-testid={testId}
      disabled={disabled}
      onMouseDown={keepFocus}
      onClick={onClick}
    >
      <Icon className="size-5" />
    </Button>
  )
}
