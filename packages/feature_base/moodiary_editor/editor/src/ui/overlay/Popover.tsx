import { useCallback, useEffect, useImperativeHandle, useState, type ReactNode, type Ref } from 'react'
import { createPortal } from 'react-dom'
import { post } from '@/core/bridge/post'
import { useAnchoredFloating } from './floating'

export interface PopoverHandle {
  open(anchor: HTMLElement): void
  close(): void
}

interface PopoverProps {
  ref?: Ref<PopoverHandle>
  label?: string
  className?: string
  children?: ReactNode
}

export default function Popover({ ref, label, className, children }: PopoverProps) {
  const [anchor, setAnchor] = useState<HTMLElement | null>(null)
  const open = anchor !== null
  const { refs, floatingStyles, isPositioned } = useAnchoredFloating(anchor)

  const close = useCallback((): void => setAnchor(null), [])

  // React 的 touchstart 是 passive，preventDefault 无效，只能原生非 passive 监听
  const bindBackdrop = useCallback(
    (el: HTMLDivElement) => {
      const onTouch = (e: TouchEvent): void => {
        e.preventDefault()
        close()
      }
      el.addEventListener('touchstart', onTouch, { passive: false })
      return () => el.removeEventListener('touchstart', onTouch)
    },
    [close],
  )

  useImperativeHandle(ref, () => ({ open: (el) => setAnchor(el), close }), [close])

  // 关闭回执在提交后才发，选项触发的消息总排在它前面，Flutter 能先接住再放开键盘
  useEffect(() => {
    if (!open) return
    post('overlay', { open: true })
    return () => post('overlay', { open: false })
  }, [open])

  if (!open) return null
  return createPortal(
    <>
      <div
        ref={bindBackdrop}
        className="md-popover-backdrop"
        onMouseDown={(e) => {
          e.preventDefault()
          close()
        }}
      />
      <div
        ref={refs.setFloating}
        className={`md-popover${className ? ` ${className}` : ''}`}
        style={{ ...floatingStyles, visibility: isPositioned ? 'visible' : 'hidden' }}
        role="dialog"
        aria-label={label}
        onMouseDown={(e) => e.preventDefault()}
      >
        {children}
      </div>
    </>,
    document.body,
  )
}
