import type { ChainedCommands, Editor } from '@tiptap/core'
import {
  Bold,
  Code,
  Heading1,
  Heading2,
  Heading3,
  Italic,
  List,
  ListChecks,
  ListOrdered,
  Pilcrow,
  Quote,
  SquareCode,
  Strikethrough,
  Underline,
} from 'lucide-react'
import type { ComponentType } from 'react'
import type { MessageKey } from '@/core/i18n'

export type ToolIcon = ComponentType<{ className?: string }>

export interface ToolbarState {
  bold: boolean
  italic: boolean
  underline: boolean
  strike: boolean
  code: boolean
  bulletList: boolean
  orderedList: boolean
  taskList: boolean
  blockquote: boolean
  codeBlock: boolean
  heading: boolean
  h1: boolean
  h2: boolean
  h3: boolean
  table: boolean
}

export const readToolbarState = (ed: Editor): ToolbarState => ({
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
})

export interface FormatTool {
  key: keyof ToolbarState
  title: MessageKey
  icon: ToolIcon
  run: (c: ChainedCommands) => ChainedCommands
}

export const FORMAT_TOOLS: FormatTool[] = [
  { key: 'bold', title: 'toolbar.bold', icon: Bold, run: (c) => c.toggleBold() },
  { key: 'italic', title: 'toolbar.italic', icon: Italic, run: (c) => c.toggleItalic() },
  { key: 'underline', title: 'toolbar.underline', icon: Underline, run: (c) => c.toggleUnderline() },
  { key: 'strike', title: 'toolbar.strike', icon: Strikethrough, run: (c) => c.toggleStrike() },
  { key: 'code', title: 'toolbar.code', icon: Code, run: (c) => c.toggleCode() },
  { key: 'bulletList', title: 'toolbar.bulletList', icon: List, run: (c) => c.toggleBulletList() },
  { key: 'orderedList', title: 'toolbar.orderedList', icon: ListOrdered, run: (c) => c.toggleOrderedList() },
  { key: 'taskList', title: 'toolbar.taskList', icon: ListChecks, run: (c) => c.toggleTaskList() },
  { key: 'blockquote', title: 'toolbar.quote', icon: Quote, run: (c) => c.toggleBlockquote() },
  { key: 'codeBlock', title: 'toolbar.codeBlock', icon: SquareCode, run: (c) => c.toggleCodeBlock() },
]

export interface TableOp {
  key: string
  label: MessageKey
  title: MessageKey
  run: (c: ChainedCommands) => ChainedCommands
}

export const TABLE_OPS: TableOp[] = [
  { key: 'rowAfter', label: 'toolbar.rowAfterLabel', title: 'toolbar.rowAfter', run: (c) => c.addRowAfter() },
  { key: 'delRow', label: 'toolbar.deleteRowLabel', title: 'toolbar.deleteRow', run: (c) => c.deleteRow() },
  { key: 'colAfter', label: 'toolbar.columnAfterLabel', title: 'toolbar.columnAfter', run: (c) => c.addColumnAfter() },
  { key: 'delCol', label: 'toolbar.deleteColumnLabel', title: 'toolbar.deleteColumn', run: (c) => c.deleteColumn() },
  { key: 'delTable', label: 'toolbar.deleteTableLabel', title: 'toolbar.deleteTable', run: (c) => c.deleteTable() },
]

export type HeadingKey = 'paragraph' | 'h1' | 'h2' | 'h3'

export const HEADING_ITEMS: { key: HeadingKey; label: MessageKey; icon: ToolIcon }[] = [
  { key: 'paragraph', label: 'toolbar.paragraph', icon: Pilcrow },
  { key: 'h1', label: 'toolbar.heading1', icon: Heading1 },
  { key: 'h2', label: 'toolbar.heading2', icon: Heading2 },
  { key: 'h3', label: 'toolbar.heading3', icon: Heading3 },
]

export const headingActive = (s: ToolbarState, key: HeadingKey): boolean =>
  key === 'paragraph' ? !s.heading : s[key]

export const currentHeadingIcon = (s: ToolbarState): ToolIcon =>
  s.h1 ? Heading1 : s.h2 ? Heading2 : s.h3 ? Heading3 : Pilcrow

// 选「正文」= 关掉当前标题层级
export function toggleHeading(c: ChainedCommands, s: ToolbarState, key: HeadingKey): ChainedCommands {
  const level = key === 'paragraph' ? (s.h1 ? 1 : s.h2 ? 2 : s.h3 ? 3 : 1) : Number(key.slice(1))
  return c.toggleHeading({ level: level as 1 | 2 | 3 })
}
