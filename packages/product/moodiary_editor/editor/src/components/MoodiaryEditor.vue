<script setup lang="ts">
// TipTap 经 @tiptap/vue-3 的 useEditor 接入：编辑器生命周期随组件自动管理（卸载即销毁），且为
// 将来 video/audio/自定义块的 Vue node view（VueNodeViewRenderer）提供 app 上下文。onCreate
// （实例就绪）时把 kit 的命令式 [EditorApi] 绑定到 bridge 并上报 ready。editor 的 options 与 api
// 共享同一份闭包状态，由 createEditorKit 统一产出（见 ../editor/tiptap）。
//
// 工具栏（EditorToolbar）由本组件按 platform 摆放：桌面置顶、移动置底（CSS 见
// ../styles/moodiary-editor.css）。仅在可编辑态显示；可编辑性运行期可由 Flutter 经 bridge 切换,
// 故用本地 editable ref 反映（onEditableChange 回调驱动,见 kit）。
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import { createEditorKit } from '../editor/tiptap'
import { bindApi, emitChange, markReady } from '../bridge'
import { post } from '../bridge/post'
import { saveStatus } from '../bridge/save-status'
import EditorToolbar from './EditorToolbar.vue'
import EditorSearchBar from './EditorSearchBar.vue'
import { openSearch } from '../editor/search'

const props = defineProps<{
  editable: boolean
  placeholder: string
  platform: 'mobile' | 'desktop'
}>()

const editable = ref(props.editable)
const charCount = ref(0)

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
    // 字数：transaction 即更新（含 setContent 这类 emitUpdate:false 的程序化加载也会触发 transaction）。
    const updateCount = (): void => {
      charCount.value = instance.storage.characterCount?.characters?.() ?? 0
    }
    instance.on('transaction', updateCount)
    updateCount()
  },
})

const showToolbar = computed(() => editable.value)

// 右下角自动保存气泡：仅 saving/saved/failed 显示文案，其它（idle 等）不显示。状态由 Flutter
// 经 bridge setSaveStatus 推入（见 ../bridge/save-status）。
const saveLabel = computed(() => {
  switch (saveStatus.value) {
    case 'saving':
      return '保存中…'
    case 'saved':
      return '已保存'
    case 'failed':
      return '保存失败'
    default:
      return ''
  }
})

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
  if (props.platform === 'mobile') window.addEventListener('resize', onViewportResize)
  window.addEventListener('keydown', onKeydown)
})
onBeforeUnmount(() => {
  window.removeEventListener('resize', onViewportResize)
  window.removeEventListener('keydown', onKeydown)
  cancelAnimationFrame(scrollRaf)
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
      <EditorContent :editor="editor" class="moodiary-editor" />
      <div v-if="editable" class="moodiary-statusbar">
        <span
          v-if="saveLabel"
          class="moodiary-savestatus"
          :data-state="saveStatus"
          >{{ saveLabel }}</span
        >
        <span class="moodiary-wordcount">{{ charCount }} 字</span>
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
