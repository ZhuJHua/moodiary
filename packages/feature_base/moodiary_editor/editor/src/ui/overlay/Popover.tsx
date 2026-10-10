import {
  useCallback,
  useEffect,
  useImperativeHandle,
  useLayoutEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
  type Ref,
} from 'react'
import { createPortal } from 'react-dom'
import { dismissKeyboard } from '@/core/editor/keyboard'
import { closeOverlay, openOverlay, type Overlay } from '@/core/state/overlay'

export interface PopoverHandle {
  open(anchor: HTMLElement): void
  close(): void
  isOpen(): boolean
}

const GAP = 6
const PAD = 8

export default function Popover({
  ref,
  label,
  keepFocus,
  panelClass,
  onClosed,
  children,
}: {
  ref?: Ref<PopoverHandle>
  label?: string
  keepFocus?: boolean
  panelClass?: string
  onClosed?: () => void
  children?: ReactNode
}) {
  const [anchor, setAnchor] = useState<HTMLElement | null>(null)
  const panel = useRef<HTMLDivElement>(null)
  const [style, setStyle] = useState<CSSProperties>({})
  const onClosedRef = useRef(onClosed)
  onClosedRef.current = onClosed
  const openRef = useRef(false)
  const open = anchor !== null

  const close = useCallback((): void => {
    if (!openRef.current) return
    openRef.current = false
    setAnchor(null)
    onClosedRef.current?.()
  }, [])

  const place = useCallback((): void => {
    const box = panel.current
    if (!anchor || !box) return
    const rect = anchor.getBoundingClientRect()
    const vv = window.visualViewport
    const top0 = vv?.offsetTop ?? 0
    const bottom0 = top0 + (vv?.height ?? window.innerHeight)
    const width = Math.min(box.offsetWidth, window.innerWidth - PAD * 2)
    const height = box.scrollHeight
    let top: number
    let origin = 'top center'
    if (height <= bottom0 - rect.bottom - GAP - PAD) {
      top = rect.bottom + GAP
    } else if (height <= rect.top - top0 - GAP - PAD) {
      top = rect.top - GAP - height
      origin = 'bottom center'
    } else {
      top = Math.max(top0 + PAD, bottom0 - PAD - height)
      origin = 'center'
    }
    let left = rect.left
    if (left + width > window.innerWidth - PAD) left = window.innerWidth - width - PAD
    if (left < PAD) left = PAD
    setStyle({
      left: `${Math.round(left)}px`,
      top: `${Math.round(top)}px`,
      maxHeight: `${Math.round(bottom0 - PAD - top)}px`,
      transformOrigin: origin,
    })
  }, [anchor])

  useLayoutEffect(() => {
    if (!open) return
    place()
    const vv = window.visualViewport
    window.addEventListener('resize', place)
    vv?.addEventListener('resize', place)
    return () => {
      window.removeEventListener('resize', place)
      vv?.removeEventListener('resize', place)
    }
  }, [open, place])

  useEffect(() => {
    if (!open) return
    const overlay: Overlay = { dismiss: close }
    openOverlay(overlay)
    return () => closeOverlay(overlay)
  }, [open, close])

  useImperativeHandle(
    ref,
    () => ({
      open: (el) => {
        if (!keepFocus) dismissKeyboard()
        openRef.current = true
        setAnchor(el)
      },
      close,
      isOpen: () => anchor !== null,
    }),
    [anchor, close, keepFocus],
  )

  // React 把 touchstart 注册成 passive，preventDefault 无效；拦截层要原生非 passive 监听才能吃掉整段触摸
  const backdropRef = useCallback(
    (el: HTMLDivElement | null) => {
      if (!el) return
      const onTouch = (e: TouchEvent): void => {
        e.preventDefault()
        close()
      }
      el.addEventListener('touchstart', onTouch, { passive: false })
      return () => el.removeEventListener('touchstart', onTouch)
    },
    [close],
  )

  if (!open) return null
  return createPortal(
    <>
      <div
        ref={backdropRef}
        className="fixed inset-0 z-[70]"
        onMouseDown={(e) => {
          e.preventDefault()
          close()
        }}
      />
      <div
        ref={panel}
        className={`moodiary-popover ${panelClass ?? ''}`}
        style={style}
        role="dialog"
        aria-label={label}
        onMouseDown={(e) => {
          if (keepFocus) e.preventDefault()
        }}
      >
        {children}
      </div>
    </>,
    document.body,
  )
}
