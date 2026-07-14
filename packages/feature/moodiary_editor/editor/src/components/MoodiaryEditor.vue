<script setup lang="ts">
// TipTap 经 @tiptap/vue-3 的 useEditor 接入：编辑器生命周期随组件自动管理（卸载即销毁），且为
// 将来 video/audio/自定义块的 Vue node view（VueNodeViewRenderer）提供 app 上下文。onCreate
// （实例就绪）时把 kit 的命令式 [EditorApi] 绑定到 bridge 并上报 ready。editor 的 options 与 api
// 共享同一份闭包状态，由 createEditorKit 统一产出（见 ../editor/tiptap）。
//
// 工具栏（EditorToolbar）由本组件按 platform 摆放：桌面置顶、移动置底（CSS 见
// ../styles/moodiary-editor.css）。仅在可编辑态显示；可编辑性运行期可由 Flutter 经 bridge 切换,
// 故用本地 editable ref 反映（onEditableChange 回调驱动,见 kit）。
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import { createEditorKit } from '../editor/tiptap'
import { bindApi, emitChange, markReady } from '../bridge'
import { post } from '../bridge/post'
import { bindScrollViewport } from '../bridge/scroll'
import { registerTitleFocus, title } from '../bridge/title'
import EditorToolbar from './EditorToolbar.vue'
import EditorSearchBar from './EditorSearchBar.vue'
import { openSearch } from '../editor/search'

const props = defineProps<{
  editable: boolean
  placeholder: string
  platform: 'mobile' | 'desktop'
}>()

const editable = ref(props.editable)

const kit = createEditorKit({
  editable: props.editable,
  placeholder: props.placeholder,
  onChange: emitChange,
  onEditableChange: (value) => {
    editable.value = value
  },
})

const editor = useEditor({
  ...kit.options,
  onCreate: ({ editor: instance }) => {
    kit.attach(instance)
    bindApi(kit.api)
    markReady()
    // 内容变化可能增删标题 → 重算当前标题（rAF 合并）。
    instance.on('transaction', onViewportScroll)
  },
})

const showToolbar = computed(() => editable.value)

// —— 顶部标题区（不进正文文档，单独映射 Diary.title），随正文一起滚动 ——
// title 为 bridge 共享 ref（Flutter setTitle 推入）。非受控写法：程序化推入经下方 watch 同步进 DOM
// （仅值不同才写，避免跳光标）；用户输入只读 DOM 回传 titleChange，不回写 DOM（避免中文输入法被打断，
// 也规避 v-model 对导入 ref 写回不可靠的问题）。
const titleEl = ref<HTMLTextAreaElement>()
const viewportEl = ref<HTMLElement>()
let titleComposing = false
function autoGrowTitle(): void {
  const el = titleEl.value
  if (!el) return
  el.style.height = 'auto'
  el.style.height = `${el.scrollHeight}px`
}
// 程序化推入（打开日记 setTitle）→ 同步进 DOM（值相同则跳过，避免打断输入 / 跳光标）。
watch(title, (v) => {
  const el = titleEl.value
  if (el && el.value !== v) {
    el.value = v
    nextTick(autoGrowTitle)
  }
})
function onTitleInput(e: Event): void {
  const el = e.target as HTMLTextAreaElement
  title.value = el.value // 驱动 v-show（watch 里值相同会跳过回写）
  autoGrowTitle()
  if (titleComposing) return // 组合输入中（拼音）先不回传，等 compositionend
  post('titleChange', el.value)
}
function onTitleCompositionStart(): void {
  titleComposing = true
}
function onTitleCompositionEnd(e: Event): void {
  titleComposing = false
  const el = e.target as HTMLTextAreaElement
  title.value = el.value
  post('titleChange', el.value)
}
// 标题回车 → 跳到正文起始（符合"标题→正文"书写流）；组合输入中的回车用于确认候选，不劫持。
function onTitleKeydown(e: KeyboardEvent): void {
  if (e.key !== 'Enter' || e.isComposing) return
  e.preventDefault()
  editor.value?.commands.focus('start')
}
// 标题焦点变化上报（'title' / ''），与正文的 onFocus/onBlur 共用 focusChange 事件。
function onTitleFocus(): void {
  post('focusChange', 'title')
}
function onTitleBlur(): void {
  post('focusChange', '')
}

// —— 目录（TOC）滚动联动 ——
// 视口滚动 / 内容变化时算出「当前顶部可见的最后一个标题」下标（文档序，与 Dart TiptapContent.headings
// 一致），仅在变化时回传 activeHeading，供 Flutter 高亮目录项。跳转由 bridge.scrollToHeading 反向驱动。
let activeHeadingIndex = -1
let spyRaf = 0
function computeActiveHeading(): void {
  const vp = viewportEl.value
  if (!vp) return
  const heads = vp.querySelectorAll<HTMLElement>(
    '.ProseMirror h1, .ProseMirror h2, .ProseMirror h3, .ProseMirror h4, .ProseMirror h5, .ProseMirror h6',
  )
  const vpTop = vp.getBoundingClientRect().top
  let active = heads.length > 0 ? 0 : -1
  heads.forEach((h, i) => {
    if (h.getBoundingClientRect().top - vpTop <= 12) active = i
  })
  if (active !== activeHeadingIndex) {
    activeHeadingIndex = active
    post('activeHeading', active)
  }
}
function onViewportScroll(): void {
  cancelAnimationFrame(spyRaf)
  spyRaf = requestAnimationFrame(computeActiveHeading)
}

// 工具栏媒体按钮 → 通知 Flutter 弹原生选取（存盘后经 insertMedia/insertAudio/insertVideo 回插）。
function onPickImage(): void {
  post('pickImage')
}
function onPickAudio(): void {
  post('pickAudio')
}
function onPickVideo(): void {
  post('pickVideo')
}
// 工具栏首位「详情」→ 通知 Flutter 打开元信息面板（原生实现）。
function onOpenDetails(): void {
  post('details')
}

// 移动端：点击聚焦后软键盘弹出 → webview 高度被 Flutter（Scaffold.resizeToAvoidBottomInset）压缩 →
// window resize。ProseMirror 不会因 resize 自动重滚、点击也不触发滚动,故这里把光标重新滚进视口,
// 避免它被压到工具栏/键盘下方看不见（尤其点击末行时）。rAF 合并键盘动画期间的多次 resize。
let scrollRaf = 0
function onViewportResize(): void {
  const ed = editor.value
  if (!ed || !ed.isEditable || !ed.isFocused) return
  cancelAnimationFrame(scrollRaf)
  scrollRaf = requestAnimationFrame(() => ed.commands.scrollIntoView())
}
// Cmd/Ctrl+F 打开查找条（仅可编辑态；webview 内无浏览器查找栏抢这个快捷键）。
function onKeydown(e: KeyboardEvent): void {
  if ((e.metaKey || e.ctrlKey) && (e.key === 'f' || e.key === 'F')) {
    if (!editable.value) return
    e.preventDefault()
    openSearch()
  }
}
onMounted(() => {
  nextTick(autoGrowTitle)
  registerTitleFocus(() => titleEl.value?.focus())
  bindScrollViewport(viewportEl.value ?? null)
  viewportEl.value?.addEventListener('scroll', onViewportScroll, { passive: true })
  if (props.platform === 'mobile') window.addEventListener('resize', onViewportResize)
  window.addEventListener('keydown', onKeydown)
})
onBeforeUnmount(() => {
  registerTitleFocus(null)
  bindScrollViewport(null)
  viewportEl.value?.removeEventListener('scroll', onViewportScroll)
  window.removeEventListener('resize', onViewportResize)
  window.removeEventListener('keydown', onKeydown)
  cancelAnimationFrame(scrollRaf)
  cancelAnimationFrame(spyRaf)
})
</script>

<template>
  <div class="moodiary-editor-root" :data-platform="platform">
    <EditorToolbar
      v-if="editor && showToolbar && platform === 'desktop'"
      :editor="editor"
      :platform="platform"
      @pick-image="onPickImage"
      @pick-audio="onPickAudio"
      @pick-video="onPickVideo"
      @open-details="onOpenDetails"
    />
    <!-- 桌面：查找条置于工具栏下方 -->
    <EditorSearchBar v-if="platform === 'desktop'" :platform="platform" />
    <div class="moodiary-editor-scroll">
      <div ref="viewportEl" class="moodiary-editor-viewport">
        <textarea
          ref="titleEl"
          v-show="editable || title.trim().length > 0"
          class="moodiary-title"
          rows="1"
          :readonly="!editable"
          :placeholder="editable ? '标题' : ''"
          @input="onTitleInput"
          @compositionstart="onTitleCompositionStart"
          @compositionend="onTitleCompositionEnd"
          @keydown="onTitleKeydown"
          @focus="onTitleFocus"
          @blur="onTitleBlur"
        ></textarea>
        <EditorContent :editor="editor" class="moodiary-editor" />
      </div>
    </div>
    <!-- 移动：查找条置于工具栏上方 -->
    <EditorSearchBar v-if="platform === 'mobile'" :platform="platform" />
    <EditorToolbar
      v-if="editor && showToolbar && platform === 'mobile'"
      :editor="editor"
      :platform="platform"
      @pick-image="onPickImage"
      @pick-audio="onPickAudio"
      @pick-video="onPickVideo"
      @open-details="onOpenDetails"
    />
  </div>
</template>
