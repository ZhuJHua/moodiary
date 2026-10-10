import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { NodeSelection, type Transaction } from '@tiptap/pm/state'
import { EditorContent, useEditor } from '@tiptap/react'
import { createEditorKit } from '@/core/editor/tiptap'
import { bindApi, emitChange, markReady } from '@/core/bridge'
import { post } from '@/core/bridge/post'
import { links as linksStore, meta as metaStore } from '@/core/state/meta'
import { bindScrollViewport } from '@/core/bridge/scroll'
import { registerTitleFocus, title as titleStore } from '@/core/state/title'
import EditorToolbar, { type PickType } from '@/ui/toolbar/EditorToolbar'
import EditorSearchBar from '@/ui/EditorSearchBar'
import EditorMetaHeader from '@/ui/meta/EditorMetaHeader'
import EditorLinksPanel from '@/ui/EditorLinksPanel'
import BlockMenu from '@/ui/block/BlockMenu'
import UndoToast from '@/ui/overlay/UndoToast'
import { editable as editableStore } from '@/core/state/editable'
import { dismissKeyboard } from '@/core/editor/keyboard'
import { openSearch } from '@/core/editor/search'
import { useT } from '@/core/i18n'
import { useStore } from '@/lib/store'
import { wordCountOf } from '@/core/editor/word-count'

export default function MoodiaryEditor({
  editable: initialEditable,
  platform,
}: {
  editable: boolean
  platform: 'mobile' | 'desktop'
}) {
  const t = useT()
  const editable = useStore(editableStore)
  const meta = useStore(metaStore)
  const links = useStore(linksStore)
  const title = useStore(titleStore)

  const [kit] = useState(() =>
    createEditorKit({ editable: initialEditable, placeholder: t('content'), onChange: emitChange }),
  )
  const [options] = useState(() => Object.assign(kit.options, { immediatelyRender: true as const }))
  const editor = useEditor(options)

  const [wordCount, setWordCount] = useState(0)
  const titleEl = useRef<HTMLTextAreaElement>(null)
  const viewportEl = useRef<HTMLDivElement>(null)
  const titleComposing = useRef(false)
  const activeHeadingIndex = useRef(-1)
  const spyRaf = useRef(0)
  const scrollRaf = useRef(0)
  const viewportBottom = useRef(Infinity)

  const computeActiveHeading = useCallback((): void => {
    const vp = viewportEl.current
    if (!vp) return
    const heads = vp.querySelectorAll<HTMLElement>(
      '.ProseMirror h1, .ProseMirror h2, .ProseMirror h3, .ProseMirror h4, .ProseMirror h5, .ProseMirror h6',
    )
    const vpTop = vp.getBoundingClientRect().top
    let active = heads.length > 0 ? 0 : -1
    heads.forEach((h, i) => {
      if (h.getBoundingClientRect().top - vpTop <= 12) active = i
    })
    if (active !== activeHeadingIndex.current) {
      activeHeadingIndex.current = active
      post('activeHeading', active)
    }
  }, [])
  const onViewportScroll = useCallback((): void => {
    cancelAnimationFrame(spyRaf.current)
    spyRaf.current = requestAnimationFrame(computeActiveHeading)
  }, [computeActiveHeading])

  useEffect(() => {
    kit.attach(editor)
    bindApi(kit.api)
    markReady()
    setWordCount(wordCountOf(editor.state.doc))
    const onTx = ({ transaction }: { transaction: Transaction }): void => {
      onViewportScroll()
      if (transaction.docChanged && !editableStore.get()) setWordCount(wordCountOf(editor.state.doc))
    }
    editor.on('transaction', onTx)
    return () => {
      editor.off('transaction', onTx)
    }
  }, [editor, kit, onViewportScroll])

  useEffect(() => {
    if (!editable) setWordCount(wordCountOf(editor.state.doc))
  }, [editable, editor])

  const titleVisible = editable || title.trim().length > 0
  const autoGrowTitle = useCallback((): void => {
    const el = titleEl.current
    // 隐藏时 scrollHeight 恒为 0，量出来会把 height 钉死成 0px
    if (!el || el.offsetParent === null) return
    el.style.height = 'auto'
    el.style.height = `${el.scrollHeight}px`
  }, [])
  useLayoutEffect(() => {
    const el = titleEl.current
    if (el && el.value !== title) el.value = title
    autoGrowTitle()
  }, [title, titleVisible, autoGrowTitle])

  function onTitleInput(e: React.FormEvent<HTMLTextAreaElement>): void {
    const el = e.currentTarget
    titleStore.set(el.value)
    autoGrowTitle()
    if (titleComposing.current) return
    post('titleChange', el.value)
  }
  function onTitleCompositionEnd(e: React.CompositionEvent<HTMLTextAreaElement>): void {
    titleComposing.current = false
    const el = e.currentTarget
    titleStore.set(el.value)
    post('titleChange', el.value)
  }
  function onTitleKeydown(e: React.KeyboardEvent<HTMLTextAreaElement>): void {
    if (e.key !== 'Enter' || e.nativeEvent.isComposing) return
    e.preventDefault()
    editor.commands.focus('start')
  }

  const pick = useCallback((type: PickType): void => {
    dismissKeyboard()
    post(type)
  }, [])

  useEffect(() => {
    const vp = viewportEl.current
    registerTitleFocus(() => titleEl.current?.focus())
    bindScrollViewport(vp)
    vp?.addEventListener('scroll', onViewportScroll, { passive: true })
    viewportBottom.current = vp?.getBoundingClientRect().bottom ?? Infinity
    const onViewportResize = (): void => {
      autoGrowTitle()
      const box = viewportEl.current
      if (!box) return
      const bounds = box.getBoundingClientRect()
      const bottomBefore = viewportBottom.current
      viewportBottom.current = bounds.bottom
      if (!editor.isEditable || !editor.isFocused) return
      const { selection } = editor.state
      const caret = editor.view.coordsAtPos(
        selection instanceof NodeSelection ? selection.from : selection.head,
      )
      if (caret.bottom < bounds.top || caret.top > bottomBefore) return
      cancelAnimationFrame(scrollRaf.current)
      scrollRaf.current = requestAnimationFrame(() => editor.commands.scrollIntoView())
    }
    const onKeydown = (e: KeyboardEvent): void => {
      if ((e.metaKey || e.ctrlKey) && (e.key === 'f' || e.key === 'F')) {
        if (!editableStore.get()) return
        e.preventDefault()
        openSearch()
      }
    }
    if (platform === 'mobile') window.addEventListener('resize', onViewportResize)
    window.addEventListener('keydown', onKeydown)
    return () => {
      registerTitleFocus(null)
      bindScrollViewport(null)
      vp?.removeEventListener('scroll', onViewportScroll)
      window.removeEventListener('resize', onViewportResize)
      window.removeEventListener('keydown', onKeydown)
      cancelAnimationFrame(scrollRaf.current)
      cancelAnimationFrame(spyRaf.current)
    }
  }, [editor, platform, onViewportScroll, autoGrowTitle])

  const showLinks =
    !editable && links != null && links.outgoing.length + links.incoming.length > 0

  return (
    <div className="moodiary-editor-root" data-platform={platform}>
      {editable && platform === 'desktop' && (
        <EditorToolbar editor={editor} platform={platform} onPick={pick} />
      )}
      {platform === 'desktop' && <EditorSearchBar platform={platform} />}
      <div className="moodiary-editor-scroll">
        <div ref={viewportEl} className="moodiary-editor-viewport">
          {meta && <EditorMetaHeader meta={meta} editable={editable} wordCount={wordCount} />}
          <textarea
            ref={titleEl}
            className="moodiary-title"
            style={titleVisible ? undefined : { display: 'none' }}
            rows={1}
            readOnly={!editable}
            placeholder={editable ? t('titlePlaceholder') : ''}
            onInput={onTitleInput}
            onCompositionStart={() => {
              titleComposing.current = true
            }}
            onCompositionEnd={onTitleCompositionEnd}
            onKeyDown={onTitleKeydown}
            onFocus={() => post('focusChange', 'title')}
            onBlur={() => post('focusChange', '')}
          />
          <EditorContent editor={editor} className="moodiary-editor" />
          {showLinks && links && <EditorLinksPanel links={links} />}
        </div>
      </div>
      {platform === 'mobile' && <EditorSearchBar platform={platform} />}
      <UndoToast />
      {editable && platform === 'mobile' && (
        <EditorToolbar editor={editor} platform={platform} onPick={pick} />
      )}
      {editable && <BlockMenu editor={editor} />}
    </div>
  )
}
