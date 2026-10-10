import { useCallback, useEffect, useLayoutEffect, useRef, type CompositionEvent, type FormEvent, type KeyboardEvent } from 'react'
import type { Editor } from '@tiptap/core'
import { post } from '@/core/bridge/post'
import { registerTitleFocus, title as titleStore } from '@/core/state/title'
import { t } from '@/core/i18n'
import { useStore } from '@/lib/store'

// 非受控 textarea：受控写法会和 CJK 输入法的组合态打架；store 只在 Flutter 下发标题时同步进 DOM
export default function TitleField({ editor, editable }: { editor: Editor; editable: boolean }) {
  const hasTitle = useStore(titleStore, (s) => s.trim().length > 0)
  const el = useRef<HTMLTextAreaElement>(null)
  const composing = useRef(false)
  const visible = editable || hasTitle

  const autoGrow = useCallback((): void => {
    const ta = el.current
    // 隐藏时 scrollHeight 恒为 0，量出来会把 height 钉死成 0px
    if (!ta || ta.offsetParent === null) return
    ta.style.height = 'auto'
    ta.style.height = `${ta.scrollHeight}px`
  }, [])

  useEffect(() => {
    const sync = (): void => {
      const ta = el.current
      const value = titleStore.get()
      if (ta && ta.value !== value) {
        ta.value = value
        autoGrow()
      }
    }
    sync()
    const unsubscribe = titleStore.subscribe(sync)
    registerTitleFocus(() => el.current?.focus())
    window.addEventListener('resize', autoGrow)
    return () => {
      unsubscribe()
      registerTitleFocus(null)
      window.removeEventListener('resize', autoGrow)
    }
  }, [autoGrow])

  useLayoutEffect(() => {
    autoGrow()
  }, [visible, autoGrow])

  function onInput(e: FormEvent<HTMLTextAreaElement>): void {
    const value = e.currentTarget.value
    titleStore.set(value)
    autoGrow()
    if (!composing.current) post('titleChange', value)
  }
  function onCompositionEnd(e: CompositionEvent<HTMLTextAreaElement>): void {
    composing.current = false
    const value = e.currentTarget.value
    titleStore.set(value)
    post('titleChange', value)
  }
  function onKeyDown(e: KeyboardEvent<HTMLTextAreaElement>): void {
    if (e.key !== 'Enter' || e.nativeEvent.isComposing) return
    e.preventDefault()
    editor.commands.focus('start')
  }

  return (
    <textarea
      ref={el}
      className="moodiary-title"
      style={visible ? undefined : { display: 'none' }}
      rows={1}
      readOnly={!editable}
      placeholder={editable ? t('titlePlaceholder') : ''}
      onInput={onInput}
      onCompositionStart={() => {
        composing.current = true
      }}
      onCompositionEnd={onCompositionEnd}
      onKeyDown={onKeyDown}
      onFocus={() => post('focusChange', 'title')}
      onBlur={() => post('focusChange', '')}
    />
  )
}
