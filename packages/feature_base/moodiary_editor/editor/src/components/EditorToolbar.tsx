import { useEffect, useState, type ComponentType, type MouseEvent } from 'react'
import type { Editor } from '@tiptap/core'
import { useEditorState } from '@tiptap/react'
import {
  Bold,
  Code,
  FileAudio,
  Heading1,
  Heading2,
  Heading3,
  Image,
  Italic,
  Link,
  List,
  ListChecks,
  ListOrdered,
  Mic,
  Music,
  Pilcrow,
  Quote,
  Redo2,
  Search,
  SquareCode,
  Strikethrough,
  Table,
  Underline,
  Undo2,
  Video,
} from 'lucide-react'
import { cn } from 'cn'
import { openSearch } from '../editor/search'
import { useT } from '../i18n'
import PopupMenu, { type PopupMenuItem } from './PopupMenu'
import TableGridPicker from './TableGridPicker'
import { Button } from './ui/button'
import { Separator } from './ui/separator'

export type PickType = 'pickImage' | 'pickVideo' | 'recordAudio' | 'pickAudioFile'

interface Tool {
  key: string
  title: string
  icon: ComponentType<{ className?: string }>
  run: () => void
  active: boolean
}

const PW = 184
const PH = 214
const M = 8

const prevent = (e: MouseEvent): void => e.preventDefault()

export default function EditorToolbar({
  editor,
  platform,
  onPick,
}: {
  editor: Editor
  platform: 'mobile' | 'desktop'
  onPick: (type: PickType) => void
}) {
  const t = useT()
  const mobile = platform === 'mobile'

  const s = useEditorState({
    editor,
    selector: ({ editor: ed }) => ({
      bold: ed.isActive('bold'),
      italic: ed.isActive('italic'),
      underline: ed.isActive('underline'),
      strike: ed.isActive('strike'),
      code: ed.isActive('code'),
      bulletList: ed.isActive('bulletList'),
      orderedList: ed.isActive('orderedList'),
      taskList: ed.isActive('taskList'),
      blockquote: ed.isActive('blockquote'),
      codeBlock: ed.isActive('codeBlock'),
      heading: ed.isActive('heading'),
      h1: ed.isActive('heading', { level: 1 }),
      h2: ed.isActive('heading', { level: 2 }),
      h3: ed.isActive('heading', { level: 3 }),
      table: ed.isActive('table'),
    }),
  })

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

  const iconSize = mobile ? 'icon-lg' : 'icon'
  const iconClass = mobile ? 'size-10' : undefined
  const activeClass = 'bg-accent text-primary'

  const tools: Tool[] = [
    { key: 'bold', title: t('toolbar.bold'), icon: Bold, run: () => chain().toggleBold().run(), active: s.bold },
    { key: 'italic', title: t('toolbar.italic'), icon: Italic, run: () => chain().toggleItalic().run(), active: s.italic },
    { key: 'underline', title: t('toolbar.underline'), icon: Underline, run: () => chain().toggleUnderline().run(), active: s.underline },
    { key: 'strike', title: t('toolbar.strike'), icon: Strikethrough, run: () => chain().toggleStrike().run(), active: s.strike },
    { key: 'code', title: t('toolbar.code'), icon: Code, run: () => chain().toggleCode().run(), active: s.code },
    { key: 'bullet', title: t('toolbar.bulletList'), icon: List, run: () => chain().toggleBulletList().run(), active: s.bulletList },
    { key: 'ordered', title: t('toolbar.orderedList'), icon: ListOrdered, run: () => chain().toggleOrderedList().run(), active: s.orderedList },
    { key: 'task', title: t('toolbar.taskList'), icon: ListChecks, run: () => chain().toggleTaskList().run(), active: s.taskList },
    { key: 'quote', title: t('toolbar.quote'), icon: Quote, run: () => chain().toggleBlockquote().run(), active: s.blockquote },
    { key: 'codeBlock', title: t('toolbar.codeBlock'), icon: SquareCode, run: () => chain().toggleCodeBlock().run(), active: s.codeBlock },
  ]

  const tableOps: { key: string; label: string; title: string; run: () => void }[] = [
    { key: 'rowAfter', label: t('toolbar.rowAfterLabel'), title: t('toolbar.rowAfter'), run: () => chain().addRowAfter().run() },
    { key: 'delRow', label: t('toolbar.deleteRowLabel'), title: t('toolbar.deleteRow'), run: () => chain().deleteRow().run() },
    { key: 'colAfter', label: t('toolbar.columnAfterLabel'), title: t('toolbar.columnAfter'), run: () => chain().addColumnAfter().run() },
    { key: 'delCol', label: t('toolbar.deleteColumnLabel'), title: t('toolbar.deleteColumn'), run: () => chain().deleteColumn().run() },
    { key: 'delTable', label: t('toolbar.deleteTableLabel'), title: t('toolbar.deleteTable'), run: () => chain().deleteTable().run() },
  ]

  const [tableOpen, setTableOpen] = useState(false)
  const [tablePos, setTablePos] = useState({ left: 0, top: 0 })
  function openTablePicker(e: MouseEvent<HTMLElement>): void {
    const rect = e.currentTarget.getBoundingClientRect()
    const vw = window.innerWidth
    const vh = window.innerHeight
    let left = rect.left
    if (left + PW > vw - M) left = vw - PW - M
    if (left < M) left = M
    let top = rect.bottom + 4
    if (top + PH > vh - M) top = rect.top - PH - 4
    if (top < M) top = M
    setTablePos({ left: Math.round(left), top: Math.round(top) })
    setTableOpen(true)
  }
  function onPickTable(rows: number, cols: number): void {
    chain().insertTable({ rows, cols, withHeaderRow: true }).run()
    setTableOpen(false)
  }

  const [audioMenuOpen, setAudioMenuOpen] = useState(false)
  const audioItems: PopupMenuItem[] = [
    { key: 'recordAudio', label: t('audio.fromRecord'), icon: Mic, active: false },
    { key: 'pickAudioFile', label: t('audio.fromFile'), icon: FileAudio, active: false },
  ]

  const [headingMenuOpen, setHeadingMenuOpen] = useState(false)
  const headingItems: PopupMenuItem[] = [
    { key: 'paragraph', label: t('toolbar.paragraph'), icon: Pilcrow, active: !s.heading },
    { key: 'h1', label: t('toolbar.heading1'), icon: Heading1, active: s.h1 },
    { key: 'h2', label: t('toolbar.heading2'), icon: Heading2, active: s.h2 },
    { key: 'h3', label: t('toolbar.heading3'), icon: Heading3, active: s.h3 },
  ]
  function onHeadingSelect(key: string): void {
    if (key === 'paragraph') {
      const level = s.h1 ? 1 : s.h2 ? 2 : s.h3 ? 3 : 1
      chain().toggleHeading({ level }).run()
    } else if (key === 'h1') {
      chain().toggleHeading({ level: 1 }).run()
    } else if (key === 'h2') {
      chain().toggleHeading({ level: 2 }).run()
    } else if (key === 'h3') {
      chain().toggleHeading({ level: 3 }).run()
    }
  }
  const HeadingIcon = s.h1 ? Heading1 : s.h2 ? Heading2 : s.h3 ? Heading3 : Pilcrow

  const divider = <Separator orientation="vertical" className="mx-1 h-5 data-vertical:self-center" />

  return (
    <div
      className={cn(
        'moodiary-toolbar no-scrollbar flex items-center gap-0.5 overflow-x-auto bg-background px-2 py-1.5',
        mobile ? 'border-t border-border' : 'border-b border-border',
      )}
    >
      <Button
        variant="ghost"
        size={iconSize}
        className={iconClass}
        title={t('toolbar.undo')}
        data-testid="undo"
        disabled={!history.canUndo}
        onMouseDown={prevent}
        onClick={() => chain().undo().run()}
      >
        <Undo2 className="size-5" />
      </Button>
      <Button
        variant="ghost"
        size={iconSize}
        className={iconClass}
        title={t('toolbar.redo')}
        data-testid="redo"
        disabled={!history.canRedo}
        onMouseDown={prevent}
        onClick={() => chain().redo().run()}
      >
        <Redo2 className="size-5" />
      </Button>
      {divider}

      <Button
        variant="ghost"
        size={iconSize}
        className={iconClass}
        title={t('toolbar.insertImage')}
        onMouseDown={prevent}
        onClick={() => onPick('pickImage')}
      >
        <Image className="size-5" />
      </Button>
      <PopupMenu
        open={audioMenuOpen}
        onOpenChange={setAudioMenuOpen}
        items={audioItems}
        onSelect={(key) => onPick(key as 'recordAudio' | 'pickAudioFile')}
      >
        <Button
          variant="ghost"
          size={iconSize}
          className={iconClass}
          title={t('toolbar.insertAudio')}
          onMouseDown={prevent}
        >
          <Music className="size-5" />
        </Button>
      </PopupMenu>
      <Button
        variant="ghost"
        size={iconSize}
        className={iconClass}
        title={t('toolbar.insertVideo')}
        onMouseDown={prevent}
        onClick={() => onPick('pickVideo')}
      >
        <Video className="size-5" />
      </Button>
      <Button
        variant="ghost"
        size={iconSize}
        className={iconClass}
        title={t('toolbar.insertDiaryLink')}
        onMouseDown={prevent}
        onClick={() => chain().insertContent('[[').run()}
      >
        <Link className="size-5" />
      </Button>
      {divider}

      <PopupMenu
        open={headingMenuOpen}
        onOpenChange={setHeadingMenuOpen}
        items={headingItems}
        onSelect={onHeadingSelect}
      >
        <Button
          variant="ghost"
          size={iconSize}
          className={cn(iconClass, s.heading && activeClass)}
          title={t('toolbar.heading')}
          onMouseDown={prevent}
        >
          <HeadingIcon className="size-5" />
        </Button>
      </PopupMenu>
      {tools.map((tool) => {
        const Icon = tool.icon
        return (
          <Button
            key={tool.key}
            variant="ghost"
            size={iconSize}
            className={cn(iconClass, tool.active && activeClass)}
            title={tool.title}
            onMouseDown={prevent}
            onClick={tool.run}
          >
            <Icon className="size-5" />
          </Button>
        )
      })}
      {divider}

      <Button
        variant="ghost"
        size={iconSize}
        className={iconClass}
        title={t('toolbar.insertTable')}
        onMouseDown={prevent}
        onClick={openTablePicker}
      >
        <Table className="size-5" />
      </Button>
      {s.table &&
        tableOps.map((op) => (
          <Button
            key={op.key}
            variant="ghost"
            size={mobile ? 'default' : 'sm'}
            className={cn('px-2', mobile && 'h-10')}
            title={op.title}
            onMouseDown={prevent}
            onClick={op.run}
          >
            <span className="text-xs leading-none font-semibold">{op.label}</span>
          </Button>
        ))}
      {divider}

      <Button
        variant="ghost"
        size={iconSize}
        className={iconClass}
        title={t('toolbar.findReplace')}
        onMouseDown={prevent}
        onClick={openSearch}
      >
        <Search className="size-5" />
      </Button>

      {tableOpen && (
        <>
          <div
            className="fixed inset-0 z-[60]"
            onMouseDown={(e) => {
              e.preventDefault()
              setTableOpen(false)
            }}
          />
          <TableGridPicker
            className="fixed z-[61]"
            style={{ left: `${tablePos.left}px`, top: `${tablePos.top}px` }}
            onSelect={onPickTable}
          />
        </>
      )}
    </div>
  )
}
