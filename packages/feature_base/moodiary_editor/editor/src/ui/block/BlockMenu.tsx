import { useEffect, useRef, useState } from 'react'
import type { Editor } from '@tiptap/core'
import type { Node as PMNode } from '@tiptap/pm/model'
import { closeHistory } from '@tiptap/pm/history'
import { ArrowDownToLine, ArrowUpToLine, Trash2 } from 'lucide-react'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'
import WidthControl from './WidthControl'
import { insertParagraph } from '@/core/editor/block-caret'
import { blockMenu, closeBlockMenu } from '@/ui/block/block-menu'
import { hideUndoToast, showUndoToast } from '@/core/state/undo-toast'
import { t } from '@/core/i18n'
import { useStore } from '@/lib/store'

export default function BlockMenu({ editor }: { editor: Editor }) {
  const pop = useRef<PopoverHandle>(null)
  const target = useStore(blockMenu, (s) => s.target)
  const [node, setNode] = useState<PMNode | null>(null)

  useEffect(() => {
    if (!target) {
      pop.current?.close()
      return
    }
    const refresh = (): void => {
      const pos = target.getPos()
      setNode(pos == null ? null : editor.state.doc.nodeAt(pos))
    }
    refresh()
    editor.on('transaction', refresh)
    pop.current?.open(target.anchor)
    return () => {
      editor.off('transaction', refresh)
    }
  }, [editor, target])

  const position = (): number | null => target?.getPos() ?? null
  const sizable = target !== null && target.kind !== 'audio'
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
    <Popover ref={pop} keepFocus panelClass="w-56" label={t('block.more')} onClosed={closeBlockMenu}>
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
