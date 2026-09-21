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
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  editor: Editor
  platform: 'mobile' | 'desktop'
}>()

const emit = defineEmits<{
  (e: 'pick-image'): void
  (e: 'pick-audio'): void
  (e: 'pick-video'): void
}>()

const { t } = useI18n()

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

const tools = computed<Tool[]>(() => [
  { key: 'bold', title: t('toolbar.bold'), icon: IconBold, run: () => chain().toggleBold().run(), active: () => isActive('bold') },
  { key: 'italic', title: t('toolbar.italic'), icon: IconItalic, run: () => chain().toggleItalic().run(), active: () => isActive('italic') },
  { key: 'underline', title: t('toolbar.underline'), icon: IconUnderline, run: () => chain().toggleUnderline().run(), active: () => isActive('underline') },
  { key: 'strike', title: t('toolbar.strike'), icon: IconStrike, run: () => chain().toggleStrike().run(), active: () => isActive('strike') },
  { key: 'code', title: t('toolbar.code'), icon: IconCode, run: () => chain().toggleCode().run(), active: () => isActive('code') },
  { key: 'bullet', title: t('toolbar.bulletList'), icon: IconBullet, run: () => chain().toggleBulletList().run(), active: () => isActive('bulletList') },
  { key: 'ordered', title: t('toolbar.orderedList'), icon: IconOrdered, run: () => chain().toggleOrderedList().run(), active: () => isActive('orderedList') },
  { key: 'task', title: t('toolbar.taskList'), icon: IconChecklist, run: () => chain().toggleTaskList().run(), active: () => isActive('taskList') },
  { key: 'quote', title: t('toolbar.quote'), icon: IconQuote, run: () => chain().toggleBlockquote().run(), active: () => isActive('blockquote') },
  { key: 'codeBlock', title: t('toolbar.codeBlock'), icon: IconCodeBlock, run: () => chain().toggleCodeBlock().run(), active: () => isActive('codeBlock') },
])

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
const tableOps = computed<{ key: string; label: string; title: string; run: () => void }[]>(() => [
  { key: 'rowAfter', label: t('toolbar.rowAfterLabel'), title: t('toolbar.rowAfter'), run: () => chain().addRowAfter().run() },
  { key: 'delRow', label: t('toolbar.deleteRowLabel'), title: t('toolbar.deleteRow'), run: () => chain().deleteRow().run() },
  { key: 'colAfter', label: t('toolbar.columnAfterLabel'), title: t('toolbar.columnAfter'), run: () => chain().addColumnAfter().run() },
  { key: 'delCol', label: t('toolbar.deleteColumnLabel'), title: t('toolbar.deleteColumn'), run: () => chain().deleteColumn().run() },
  { key: 'delTable', label: t('toolbar.deleteTableLabel'), title: t('toolbar.deleteTable'), run: () => chain().deleteTable().run() },
])

const headingMenuOpen = ref(false)
const headingItems = computed<PopupMenuItem[]>(() => [
  { key: 'paragraph', label: t('toolbar.paragraph'), icon: IconParagraph, active: !isActive('heading') },
  { key: 'h1', label: t('toolbar.heading1'), icon: IconH1, active: isActive('heading', { level: 1 }) },
  { key: 'h2', label: t('toolbar.heading2'), icon: IconH2, active: isActive('heading', { level: 2 }) },
  { key: 'h3', label: t('toolbar.heading3'), icon: IconH3, active: isActive('heading', { level: 3 }) },
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
      :title="t('toolbar.undo')"
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
      :title="t('toolbar.redo')"
      data-testid="redo"
      :disabled="!canRedo()"
      @mousedown.prevent
      @click="chain().redo().run()"
    >
      <IconRedo class="size-5" />
    </button>
    <span class="mx-1 h-5 w-px shrink-0 bg-base-300" />

    <button :class="[btnClass, 'btn-square']" type="button" :title="t('toolbar.insertImage')" @mousedown.prevent @click="emit('pick-image')">
      <IconImage class="size-5" />
    </button>
    <button :class="[btnClass, 'btn-square']" type="button" :title="t('toolbar.insertAudio')" @mousedown.prevent @click="emit('pick-audio')">
      <IconAudio class="size-5" />
    </button>
    <button :class="[btnClass, 'btn-square']" type="button" :title="t('toolbar.insertVideo')" @mousedown.prevent @click="emit('pick-video')">
      <IconVideo class="size-5" />
    </button>
    <button :class="[btnClass, 'btn-square']" type="button" :title="t('toolbar.insertDiaryLink')" @mousedown.prevent @click="insertLink">
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
          :title="t('toolbar.heading')"
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
      v-for="tool in tools"
      :key="tool.key"
      :class="[btnClass, tool.icon ? 'btn-square' : 'px-2', tool.active() ? 'btn-active text-primary' : '']"
      type="button"
      :title="tool.title"
      @mousedown.prevent
      @click="tool.run()"
    >
      <component :is="tool.icon" v-if="tool.icon" class="size-5" />
      <span v-else class="text-sm font-semibold leading-none">{{ tool.label }}</span>
    </button>

    <span class="mx-1 h-5 w-px shrink-0 bg-base-300" />
    <button :class="[btnClass, 'btn-square']" type="button" :title="t('toolbar.insertTable')" @mousedown.prevent @click="openTablePicker">
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
    <button :class="[btnClass, 'btn-square']" type="button" :title="t('toolbar.findReplace')" @mousedown.prevent @click="openSearch">
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
