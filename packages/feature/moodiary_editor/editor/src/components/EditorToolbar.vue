<script setup lang="ts">
// 编辑器工具栏。TipTap 是 headless 编辑器,核心不带工具栏 UI —— 这里用它的命令 API
// （editor.chain().focus().toggleXxx().run()）自建,激活态读 editor.isActive(...)。外观用 daisyUI
// 按钮（btn btn-ghost）+ Tailwind 工具类,配色跟随 --app-* / 明暗（见 ../styles/moodiary-editor.css）。
// 图标用 unplugin-icons 按需引入 Material Symbols（`~icons/material-symbols/*`，内联 SVG、tree-shake、离线）。
// 位置由 platform 决定：桌面置顶（下边框）、移动置底（上边框）。
import { computed, onBeforeUnmount, onMounted, ref, type Component } from 'vue'
import type { Editor } from '@tiptap/core'
import IconUndo from '~icons/material-symbols/undo-rounded'
import IconRedo from '~icons/material-symbols/redo-rounded'
import IconImage from '~icons/material-symbols/image-rounded'
import IconAudio from '~icons/material-symbols/music-note-rounded'
import IconVideo from '~icons/material-symbols/videocam-rounded'
import IconBold from '~icons/material-symbols/format-bold-rounded'
import IconItalic from '~icons/material-symbols/format-italic-rounded'
import IconUnderline from '~icons/material-symbols/format-underlined-rounded'
import IconStrike from '~icons/material-symbols/format-strikethrough-rounded'
import IconCode from '~icons/material-symbols/code-rounded'
import IconBullet from '~icons/material-symbols/format-list-bulleted-rounded'
import IconOrdered from '~icons/material-symbols/format-list-numbered-rounded'
import IconQuote from '~icons/material-symbols/format-quote-rounded'
import IconCodeBlock from '~icons/material-symbols/code-blocks-rounded'
import IconChecklist from '~icons/material-symbols/checklist-rounded'
import IconTable from '~icons/material-symbols/border-all-rounded'
import IconLink from '~icons/material-symbols/add-link-rounded'
import IconSearch from '~icons/material-symbols/search-rounded'
import IconTune from '~icons/material-symbols/tune-rounded'
import IconParagraph from '~icons/material-symbols/format-paragraph-rounded'
import IconH1 from '~icons/material-symbols/format-h1-rounded'
import IconH2 from '~icons/material-symbols/format-h2-rounded'
import IconH3 from '~icons/material-symbols/format-h3-rounded'
import { openSearch } from '../editor/search'
import TableGridPicker from './TableGridPicker.vue'
import PopupMenu from './PopupMenu.vue'
import type { PopupMenuItem } from './PopupMenu.vue'

const props = defineProps<{
  editor: Editor
  platform: 'mobile' | 'desktop'
}>()

// 媒体插入走原生选取（Flutter 弹选择器→存盘→insertMedia/insertAudio/insertVideo 回插）,故只发事件给宿主。
const emit = defineEmits<{
  (e: 'pick-image'): void
  (e: 'pick-audio'): void
  (e: 'pick-video'): void
  (e: 'open-details'): void
}>()

// 移动端触控目标更大（btn-md）,桌面紧凑（btn-sm）。
const btnClass = computed(
  () => `btn btn-ghost shrink-0 ${props.platform === 'mobile' ? 'btn-md' : 'btn-sm'}`,
)

// 选区 / 格式状态变化经 editor 的 transaction 事件驱动重渲染：render 时各按钮调 active() →
// 读 tick.value 建立响应依赖,bump() 自增即触发重渲染,按钮激活态随选区实时更新。
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

// 命令统一带 .focus()：执行后把焦点交回正文（配合按钮的 @mousedown.prevent,移动端点工具栏
// 不会让 contenteditable 失焦收键盘）。
const chain = () => props.editor.chain().focus()

// 撤销 / 重做。移动端没有 Mod-Z（软键盘不给这套快捷键），工具栏按钮是唯一入口，故放在最前。
// 可用性与激活态同理走 tick：每个 transaction 后重算。
const canUndo = (): boolean => {
  void tick.value
  return props.editor.can().undo()
}
const canRedo = (): boolean => {
  void tick.value
  return props.editor.can().redo()
}

// 插入日记双链：在光标处插入 `[[`，触发搜索弹层（纯编辑器侧，无需宿主回调）。
const insertLink = (): void => {
  chain().insertContent('[[').run()
}

interface Tool {
  key: string
  title: string
  /** 图标组件（unplugin-icons）；与 label 二选一。 */
  icon?: Component
  /** 文本标签（标题用 H1/H2/H3,比图标更清晰）。 */
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

// 表格：插入按钮常驻；下列行列操作仅在光标位于表格内时出现（inTable 经 isActive 响应式跟随选区）。
const inTable = (): boolean => isActive('table')

// 插入表格：点按钮弹网格选择器选尺寸（位置按按钮 rect 计算，靠近底部/右侧自动避让）。
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

// —— 标题下拉菜单 ——
const headingMenuOpen = ref(false)
const headingItems = computed<PopupMenuItem[]>(() => [
  { key: 'paragraph', label: '正文', icon: IconParagraph, active: !isActive('heading') },
  { key: 'h1', label: '一级标题', icon: IconH1, active: isActive('heading', { level: 1 }) },
  { key: 'h2', label: '二级标题', icon: IconH2, active: isActive('heading', { level: 2 }) },
  { key: 'h3', label: '三级标题', icon: IconH3, active: isActive('heading', { level: 3 }) },
])
function onHeadingSelect(key: string): void {
  if (key === 'paragraph') {
    // toggleHeading 同 level 会关掉标题 → 切回正文。
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
    <!-- 撤销 / 重做：移动端唯一入口（无 Mod-Z），故置于最前，不随工具栏横向滚动被推走 -->
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

    <!-- 详情：打开日记元信息面板（原生实现，宿主接管） -->
    <button :class="[btnClass, 'btn-square']" type="button" title="详情" @mousedown.prevent @click="emit('open-details')">
      <IconTune class="size-5" />
    </button>
    <span class="mx-1 h-5 w-px shrink-0 bg-base-300" />

    <!-- 媒体：图片 / 音频 / 视频（均走原生选取） -->
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
    <!-- 标题下拉：H1/H2/H3 收进一个按钮，图标随当前级别切换，激活时高亮 -->
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

    <!-- 表格：插入键常驻；行列操作仅在表格内出现 -->
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

    <!-- 查找/替换 -->
    <span class="mx-1 h-5 w-px shrink-0 bg-base-300" />
    <button :class="[btnClass, 'btn-square']" type="button" title="查找替换" @mousedown.prevent @click="openSearch">
      <IconSearch class="size-5" />
    </button>

    <!-- 表格尺寸选择器（点「插入表格」弹出，背景遮罩点击关闭） -->
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
