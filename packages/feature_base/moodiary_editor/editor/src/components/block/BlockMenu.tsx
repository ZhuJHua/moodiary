import { useCallback, useEffect, useRef, useState } from 'react'
import type { Editor } from '@tiptap/core'
import type { Node as PMNode } from '@tiptap/pm/model'
import { closeHistory } from '@tiptap/pm/history'
import { ArrowDownToLine, ArrowUpToLine, Trash2 } from 'lucide-react'
import Popover, { type PopoverHandle } from '../ui/Popover'
import WidthControl from './WidthControl'
import { insertParagraph } from '../../editor/block-caret'
import { blockMenu, registerBlockMenu, type BlockTarget } from '../../editor/block-menu'
import { hideUndoToast, showUndoToast } from '../../editor/undo-toast'
import { useT } from '../../i18n'

export default function BlockMenu({ editor }: { editor: Editor }) {
  const t = useT()
  const pop = useRef<PopoverHandle>(null)
  const target = useRef<BlockTarget | null>(null)
  const [kind, setKind] = useState<BlockTarget['kind'] | null>(null)
  const [node, setNode] = useState<PMNode | null>(null)

  const position = (): number | null => {
    const pos = target.current?.getPos()
    return pos == null ? null : pos
  }

  const refresh = useCallback((): void => {
    const pos = target.current?.getPos()
    setNode(pos == null ? null : editor.state.doc.nodeAt(pos))
  }, [editor])

  const onClosed = useCallback((): void => {
    editor.off('transaction', refresh)
    target.current = null
    setKind(null)
    blockMenu.set({ owner: null, previewWidth: null })
  }, [editor, refresh])

  useEffect(() => {
    registerBlockMenu((next) => {
      target.current = next
      setKind(next.kind)
      blockMenu.set({ owner: next.owner, previewWidth: null })
      refresh()
      editor.on('transaction', refresh)
      pop.current?.open(next.anchor)
    })
    return () => {
      registerBlockMenu(null)
      onClosed()
    }
  }, [editor, refresh, onClosed])

  const sizable = kind !== null && kind !== 'audio'
  const v = node?.attrs.widthPercent
  const widthPercent = typeof v === 'number' ? v : null

  function commitWidth(value: number | null): void {
    blockMenu.patch({ previewWidth: null })
    const pos = position()
    const current = node
    if (pos == null || !current) return
    editor.view.dispatch(
      editor.state.tr.setNodeMarkup(pos, undefined, { ...current.attrs, widthPercent: value }),
    )
  }

  function insert(after: boolean): void {
    const pos = position()
    const current = node
    pop.current?.close()
    if (pos == null || !current) return
    const { view } = editor
    view.focus()
    const tr = view.state.tr
    insertParagraph(tr, after ? pos + current.nodeSize : pos)
    view.dispatch(tr.scrollIntoView())
  }

  function remove(): void {
    const pos = position()
    const current = node
    pop.current?.close()
    if (pos == null || !current) return
    editor.view.dispatch(closeHistory(editor.state.tr).delete(pos, pos + current.nodeSize))
    showUndoToast(t('block.deleted'), () => editor.commands.undo())
    editor.once('update', hideUndoToast)
  }

  return (
    <Popover ref={pop} keepFocus panelClass="w-56" label={t('block.more')} onClosed={onClosed}>
      {sizable && node && (
        <>
          <WidthControl
            value={widthPercent}
            onPreview={(value) => blockMenu.patch({ previewWidth: value })}
            onCommit={commitWidth}
          />
          <div className="moodiary-pop-divider" />
        </>
      )}
      <button type="button" className="moodiary-pop-item" onClick={() => insert(false)}>
        <ArrowUpToLine />
        {t('block.insertAbove')}
      </button>
      <button type="button" className="moodiary-pop-item" onClick={() => insert(true)}>
        <ArrowDownToLine />
        {t('block.insertBelow')}
      </button>
      <button type="button" className="moodiary-pop-item is-danger" onClick={remove}>
        <Trash2 />
        {t('block.delete')}
      </button>
    </Popover>
  )
}
