import { useEffect, useRef, useState } from 'react'
import type { Editor } from '@tiptap/core'
import { useEditorState } from '@tiptap/react'
import { FileAudio, Image, Link, Mic, Music, Redo2, Search, Table, Undo2, Video } from 'lucide-react'
import { openSearch } from '@/core/editor/search'
import { t } from '@/core/i18n'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'
import PopupMenu, { type PopupMenuItem } from '@/ui/overlay/PopupMenu'
import { Button } from '@/ui/primitives/button'
import { Separator } from '@/ui/primitives/separator'
import TableGridPicker from './TableGridPicker'
import ToolbarButton from './ToolbarButton'
import {
  FORMAT_TOOLS,
  HEADING_ITEMS,
  TABLE_OPS,
  currentHeadingIcon,
  headingActive,
  readToolbarState,
  toggleHeading,
  type HeadingKey,
} from './tools'
import { keepFocus } from '@/lib/utils'

export type PickType = 'pickImage' | 'pickVideo' | 'recordAudio' | 'pickAudioFile'

export default function EditorToolbar({
  editor,
  onPick,
}: {
  editor: Editor
  onPick: (type: PickType) => void
}) {
  const s = useEditorState({ editor, selector: ({ editor: ed }) => readToolbarState(ed) })

  // loadContent 换 history 插件时不发事件，推迟到微任务再读才拿得到换完后的状态
  const [history, setHistory] = useState({ canUndo: false, canRedo: false })
  useEffect(() => {
    let queued = false
    const read = (): void => {
      if (queued) return
      queued = true
      queueMicrotask(() => {
        queued = false
        if (editor.isDestroyed) return
        const canUndo = editor.can().undo()
        const canRedo = editor.can().redo()
        setHistory((p) =>
          p.canUndo === canUndo && p.canRedo === canRedo ? p : { canUndo, canRedo },
        )
      })
    }
    read()
    editor.on('transaction', read)
    return () => {
      editor.off('transaction', read)
    }
  }, [editor])

  const chain = () => editor.chain().focus()

  const tablePop = useRef<PopoverHandle>(null)
  function onPickTable(rows: number, cols: number): void {
    chain().insertTable({ rows, cols, withHeaderRow: true }).run()
    tablePop.current?.close()
  }

  const audioItems: PopupMenuItem[] = [
    { key: 'recordAudio', label: t('audio.fromRecord'), icon: Mic, active: false },
    { key: 'pickAudioFile', label: t('audio.fromFile'), icon: FileAudio, active: false },
  ]
  const headingItems: PopupMenuItem[] = HEADING_ITEMS.map((item) => ({
    key: item.key,
    label: t(item.label),
    icon: item.icon,
    active: headingActive(s, item.key),
  }))

  const divider = <Separator orientation="vertical" className="mx-1 h-5 data-vertical:self-center" />

  return (
    <div
      className="moodiary-toolbar no-scrollbar flex items-center gap-0.5 overflow-x-auto border-t border-border bg-background px-2 py-1.5"
    >
      <ToolbarButton
        icon={Undo2}
        title={t('toolbar.undo')}
        testId="undo"
        disabled={!history.canUndo}
        onClick={() => chain().undo().run()}
      />
      <ToolbarButton
        icon={Redo2}
        title={t('toolbar.redo')}
        testId="redo"
        disabled={!history.canRedo}
        onClick={() => chain().redo().run()}
      />
      {divider}

      <ToolbarButton
        icon={Image}
        title={t('toolbar.insertImage')}
        onClick={() => onPick('pickImage')}
      />
      <PopupMenu items={audioItems} onSelect={(key) => onPick(key as PickType)}>
        <ToolbarButton icon={Music} title={t('toolbar.insertAudio')} />
      </PopupMenu>
      <ToolbarButton
        icon={Video}
        title={t('toolbar.insertVideo')}
        onClick={() => onPick('pickVideo')}
      />
      <ToolbarButton
        icon={Link}
        title={t('toolbar.insertDiaryLink')}
        onClick={() => chain().insertContent('[[').run()}
      />
      {divider}

      <PopupMenu
        items={headingItems}
        onSelect={(key) => toggleHeading(chain(), s, key as HeadingKey).run()}
      >
        <ToolbarButton
          icon={currentHeadingIcon(s)}
          title={t('toolbar.heading')}
         
          active={s.heading}
        />
      </PopupMenu>
      {FORMAT_TOOLS.map((tool) => (
        <ToolbarButton
          key={tool.key}
          icon={tool.icon}
          title={t(tool.title)}
         
          active={s[tool.key]}
          onClick={() => tool.run(chain()).run()}
        />
      ))}
      {divider}

      <ToolbarButton
        icon={Table}
        title={t('toolbar.insertTable')}
        onClick={(e) => tablePop.current?.open(e.currentTarget)}
      />
      <Popover ref={tablePop} keepFocus panelClass="w-fit">
        <TableGridPicker onSelect={onPickTable} />
      </Popover>
      {s.table &&
        TABLE_OPS.map((op) => (
          <Button
            key={op.key}
            variant="ghost"
            size="default"
            className="h-10 px-2"
            title={t(op.title)}
            onMouseDown={keepFocus}
            onClick={() => op.run(chain()).run()}
          >
            <span className="text-xs leading-none font-semibold">{t(op.label)}</span>
          </Button>
        ))}
      {divider}

      <ToolbarButton icon={Search} title={t('toolbar.findReplace')} onClick={openSearch} />
    </div>
  )
}
