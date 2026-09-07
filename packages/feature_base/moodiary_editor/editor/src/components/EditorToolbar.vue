<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, type Component } from 'vue'
import type { Editor } from '@tiptap/core'
import IconUndo from '~icons/lucide/undo-2'
import IconRedo from '~icons/lucide/redo-2'
import IconImage from '~icons/lucide/image'
import IconAudio from '~icons/lucide/music'
import IconVideo from '~icons/lucide/video'
import IconBold from '~icons/lucide/bold'
import IconItalic from '~icons/lucide/italic'
import IconUnderline from '~icons/lucide/underline'
import IconStrike from '~icons/lucide/strikethrough'
import IconCode from '~icons/lucide/code'
import IconBullet from '~icons/lucide/list'
import IconOrdered from '~icons/lucide/list-ordered'
import IconQuote from '~icons/lucide/quote'
import IconCodeBlock from '~icons/lucide/square-code'
import IconChecklist from '~icons/lucide/list-checks'
import IconTable from '~icons/lucide/table'
import IconLink from '~icons/lucide/link'
import IconSearch from '~icons/lucide/search'
import IconParagraph from '~icons/lucide/pilcrow'
import IconH1 from '~icons/lucide/heading-1'
import IconH2 from '~icons/lucide/heading-2'
import IconH3 from '~icons/lucide/heading-3'
import { openSearch } from '../editor/search'
import TableGridPicker from './TableGridPicker.vue'
import PopupMenu from './PopupMenu.vue'
import type { PopupMenuItem } from './PopupMenu.vue'

const props = defineProps<{
  editor: Editor
  platform: 'mobile' | 'desktop'
}>()

const emit = defineEmits<{
  (e: 'pick-image'): void
  (e: 'pick-audio'): void
  (e: 'pick-video'): void
}>()

const btnClass = computed(
  () => `btn btn-ghost shrink-0 ${props.platform === 'mobile' ? 'btn-md' : 'btn-sm'}`,
)

const tick = ref(0)
const bump = (): void => {
  tick.value += 1
}
onMounted(() => props.editor.on('transaction', bump))
onBeforeUnmount(() => props.editor.off('transaction', bump))

const isActive = (name: string, attrs?: Record<string, unknown>): boolean => {
  void tick.value
  return props.editor.isActive(name, attrs)
}

const chain = () => props.editor.chain().focus()

const canUndo = (): boolean => {
  void tick.value
  return props.editor.can().undo()
}
const canRedo = (): boolean => {
  void tick.value
  return props.editor.can().redo()
}

const insertLink = (): void => {
  chain().insertContent('[[').run()
}

interface Tool {
  key: string
  title: string
  icon?: Component
  label?: string
  run: () => void
  active: () => boolean
}

const tools: Tool[] = [
  { key: 'bold', title: '加粗', icon: IconBold, run: () => chain().toggleBold().run(), active: () => isActive('bold') },
  { key: 'italic', title: '斜体', icon: IconItalic, run: () => chain().toggleItalic().run(), active: () => isActive('italic') },
  { key: 'underline', title: '下划线', icon: IconUnderline, run: () => chain().toggleUnderline().run(), active: () => isActive('underline') },
  { key: 'strike', title: '删除线', icon: IconStrike, run: () => chain().toggleStrike().run(), active: () => isActive('strike') },
  { key: 'code', title: '行内代码', icon: IconCode, run: () => chain().toggleCode().run(), active: () => isActive('code') },
  { key: 'bullet', title: '无序列表', icon: IconBullet, run: () => chain().toggleBulletList().run(), active: () => isActive('bulletList') },
  { key: 'ordered', title: '有序列表', icon: IconOrdered, run: () => chain().toggleOrderedList().run(), active: () => isActive('orderedList') },
  { key: 'task', title: '任务列表', icon: IconChecklist, run: () => chain().toggleTaskList().run(), active: () => isActive('taskList') },
  { key: 'quote', title: '引用', icon: IconQuote, run: () => chain().toggleBlockquote().run(), active: () => isActive('blockquote') },
  { key: 'codeBlock', title: '代码块', icon: IconCodeBlock, run: () => chain().toggleCodeBlock().run(), active: () => isActive('codeBlock') },
]

const inTable = (): boolean => isActive('table')

const tableOpen = ref(false)
const tablePos = ref({ left: 0, top: 0 })
function openTablePicker(e: MouseEvent): void {
  const rect = (e.currentTarget as HTMLElement).getBoundingClientRect()
  const PW = 184
  const PH = 214
  const M = 8
  const vw = window.innerWidth
  const vh = window.innerHeight
  let left = rect.left
  if (left + PW > vw - M) left = vw - PW - M
  if (left < M) left = M
  let top = rect.bottom + 4
  if (top + PH > vh - M) top = rect.top - PH - 4
  if (top < M) top = M
  tablePos.value = { left: Math.round(left), top: Math.round(top) }
  tableOpen.value = true
}
function onPickTable(rows: number, cols: number): void {
  chain().insertTable({ rows, cols, withHeaderRow: true }).run()
  tableOpen.value = false
}
const tableOps: { key: string; label: string; title: string; run: () => void }[] = [
  { key: 'rowAfter', label: '+行', title: '下方插入行', run: () => chain().addRowAfter().run() },
  { key: 'delRow', label: '−行', title: '删除当前行', run: () => chain().deleteRow().run() },
  { key: 'colAfter', label: '+列', title: '右侧插入列', run: () => chain().addColumnAfter().run() },
  { key: 'delCol', label: '−列', title: '删除当前列', run: () => chain().deleteColumn().run() },
  { key: 'delTable', label: '删表', title: '删除表格', run: () => chain().deleteTable().run() },
]

const headingMenuOpen = ref(false)
const headingItems = computed<PopupMenuItem[]>(() => [
  { key: 'paragraph', label: '正文', icon: IconParagraph, active: !isActive('heading') },
  { key: 'h1', label: '一级标题', icon: IconH1, active: isActive('heading', { level: 1 }) },
  { key: 'h2', label: '二级标题', icon: IconH2, active: isActive('heading', { level: 2 }) },
  { key: 'h3', label: '三级标题', icon: IconH3, active: isActive('heading', { level: 3 }) },
])
function onHeadingSelect(key: string): void {
  if (key === 'paragraph') {
    const level = isActive('heading', { level: 1 })
      ? 1
      : isActive('heading', { level: 2 })
        ? 2
        : isActive('heading', { level: 3 })
          ? 3
          : 1
    chain().toggleHeading({ level }).run()
  } else if (key === 'h1') {
    chain().toggleHeading({ level: 1 }).run()
  } else if (key === 'h2') {
    chain().toggleHeading({ level: 2 }).run()
  } else if (key === 'h3') {
    chain().toggleHeading({ level: 3 }).run()
  }
}
</script>

<template>
  <div
    class="moodiary-toolbar no-scrollbar flex items-center gap-0.5 overflow-x-auto bg-base-100 px-2 py-1.5"
    :class="platform === 'desktop' ? 'border-b border-base-300' : 'border-t border-base-300'"
  >
    <button
      :class="[btnClass, 'btn-square']"
      type="button"
      title="撤销"
      data-testid="undo"
      :disabled="!canUndo()"
      @mousedown.prevent
      @click="chain().undo().run()"
    >
      <IconUndo class="size-5" />
    </button>
    <button
      :class="[btnClass, 'btn-square']"
      type="button"
      title="重做"
      data-testid="redo"
      :disabled="!canRedo()"
      @mousedown.prevent
      @click="chain().redo().run()"
    >
      <IconRedo class="size-5" />
    </button>
    <span class="mx-1 h-5 w-px shrink-0 bg-base-300" />

    <button :class="[btnClass, 'btn-square']" type="button" title="插入图片" @mousedown.prevent @click="emit('pick-image')">
      <IconImage class="size-5" />
    </button>
    <button :class="[btnClass, 'btn-square']" type="button" title="插入音频" @mousedown.prevent @click="emit('pick-audio')">
      <IconAudio class="size-5" />
    </button>
    <button :class="[btnClass, 'btn-square']" type="button" title="插入视频" @mousedown.prevent @click="emit('pick-video')">
      <IconVideo class="size-5" />
    </button>
    <button :class="[btnClass, 'btn-square']" type="button" title="插入日记链接" @mousedown.prevent @click="insertLink">
      <IconLink class="size-5" />
    </button>
    <span class="mx-1 h-5 w-px shrink-0 bg-base-300" />
    <PopupMenu v-model="headingMenuOpen" :items="headingItems" @select="onHeadingSelect">
      <template #trigger>
        <button
          :class="[
            btnClass,
            'btn-square',
            isActive('heading') ? 'btn-active text-primary' : '',
          ]"
          type="button"
          title="标题"
          @mousedown.prevent
        >
          <IconH1 v-if="isActive('heading', { level: 1 })" class="size-5" />
          <IconH2 v-else-if="isActive('heading', { level: 2 })" class="size-5" />
          <IconH3 v-else-if="isActive('heading', { level: 3 })" class="size-5" />
          <IconParagraph v-else class="size-5" />
        </button>
      </template>
    </PopupMenu>
    <button
      v-for="t in tools"
      :key="t.key"
      :class="[btnClass, t.icon ? 'btn-square' : 'px-2', t.active() ? 'btn-active text-primary' : '']"
      type="button"
      :title="t.title"
      @mousedown.prevent
      @click="t.run()"
    >
      <component :is="t.icon" v-if="t.icon" class="size-5" />
      <span v-else class="text-sm font-semibold leading-none">{{ t.label }}</span>
    </button>

    <span class="mx-1 h-5 w-px shrink-0 bg-base-300" />
    <button :class="[btnClass, 'btn-square']" type="button" title="插入表格" @mousedown.prevent @click="openTablePicker">
      <IconTable class="size-5" />
    </button>
    <template v-if="inTable()">
      <button
        v-for="op in tableOps"
        :key="op.key"
        :class="[btnClass, 'px-2']"
        type="button"
        :title="op.title"
        @mousedown.prevent
        @click="op.run()"
      >
        <span class="text-xs font-semibold leading-none">{{ op.label }}</span>
      </button>
    </template>

    <span class="mx-1 h-5 w-px shrink-0 bg-base-300" />
    <button :class="[btnClass, 'btn-square']" type="button" title="查找替换" @mousedown.prevent @click="openSearch">
      <IconSearch class="size-5" />
    </button>

    <template v-if="tableOpen">
      <div class="fixed inset-0 z-[60]" @mousedown.prevent="tableOpen = false" />
      <TableGridPicker
        class="fixed z-[61]"
        :style="{ left: `${tablePos.left}px`, top: `${tablePos.top}px` }"
        @select="onPickTable"
      />
    </template>
  </div>
</template>
