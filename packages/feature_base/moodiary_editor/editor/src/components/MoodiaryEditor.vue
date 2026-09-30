<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { NodeSelection, type Transaction } from '@tiptap/pm/state'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import { createEditorKit } from '../editor/tiptap'
import { bindApi, emitChange, markReady } from '../bridge'
import { post } from '../bridge/post'
import { links, meta } from '../bridge/meta'
import { bindScrollViewport } from '../bridge/scroll'
import { registerTitleFocus, title } from '../bridge/title'
import EditorToolbar from './EditorToolbar.vue'
import EditorSearchBar from './EditorSearchBar.vue'
import EditorMetaHeader from './EditorMetaHeader.vue'
import EditorLinksPanel from './EditorLinksPanel.vue'
import BlockMenu from './block/BlockMenu.vue'
import UndoToast from './ui/UndoToast.vue'
import { dismissKeyboard } from '../editor/keyboard'
import { openSearch } from '../editor/search'
import { useI18n } from 'vue-i18n'
import { wordCountOf } from '../editor/word-count'

const props = defineProps<{
  editable: boolean
  platform: 'mobile' | 'desktop'
}>()

const { t } = useI18n()

const editable = ref(props.editable)

const kit = createEditorKit({
  editable: props.editable,
  placeholder: t('content'),
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
    instance.on('transaction', onViewportScroll)
    instance.on('transaction', onDocTransaction)
    wordCount.value = wordCountOf(instance.state.doc)
  },
})

const showToolbar = computed(() => editable.value)

const wordCount = ref(0)
function refreshWordCount(): void {
  const ed = editor.value
  wordCount.value = ed ? wordCountOf(ed.state.doc) : 0
}
function onDocTransaction({ transaction }: { transaction: Transaction }): void {
  if (transaction.docChanged && !editable.value) refreshWordCount()
}
watch(editable, (v) => {
  if (!v) refreshWordCount()
})

const showLinks = computed(
  () =>
    !editable.value &&
    links.value != null &&
    links.value.outgoing.length + links.value.incoming.length > 0,
)

const titleEl = ref<HTMLTextAreaElement>()
const viewportEl = ref<HTMLElement>()
let titleComposing = false
const titleVisible = computed(() => editable.value || title.value.trim().length > 0)
function autoGrowTitle(): void {
  const el = titleEl.value
  // v-show 隐藏时 scrollHeight 恒为 0，量出来会把 height 钉死成 0px
  if (!el || el.offsetParent === null) return
  el.style.height = 'auto'
  el.style.height = `${el.scrollHeight}px`
}
watch(title, (v) => {
  const el = titleEl.value
  if (el && el.value !== v) {
    el.value = v
    nextTick(autoGrowTitle)
  }
})
watch(titleVisible, (v) => {
  if (v) nextTick(autoGrowTitle)
})
function onTitleInput(e: Event): void {
  const el = e.target as HTMLTextAreaElement
  title.value = el.value
  autoGrowTitle()
  if (titleComposing) return
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
function onTitleKeydown(e: KeyboardEvent): void {
  if (e.key !== 'Enter' || e.isComposing) return
  e.preventDefault()
  editor.value?.commands.focus('start')
}
function onTitleFocus(): void {
  post('focusChange', 'title')
}
function onTitleBlur(): void {
  post('focusChange', '')
}

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

function pick(type: string): void {
  dismissKeyboard()
  post(type)
}

let scrollRaf = 0
let viewportBottom = Infinity
function onViewportResize(): void {
  const ed = editor.value
  const vp = viewportEl.value
  if (!vp) return
  const bounds = vp.getBoundingClientRect()
  const bottomBefore = viewportBottom
  viewportBottom = bounds.bottom
  if (!ed || !ed.isEditable || !ed.isFocused) return
  const { selection } = ed.state
  const caret = ed.view.coordsAtPos(selection instanceof NodeSelection ? selection.from : selection.head)
  if (caret.bottom < bounds.top || caret.top > bottomBefore) return
  cancelAnimationFrame(scrollRaf)
  scrollRaf = requestAnimationFrame(() => ed.commands.scrollIntoView())
}
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
  viewportBottom = viewportEl.value?.getBoundingClientRect().bottom ?? Infinity
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
      @pick="pick"
    />
    <EditorSearchBar v-if="platform === 'desktop'" :platform="platform" />
    <div class="moodiary-editor-scroll">
      <div ref="viewportEl" class="moodiary-editor-viewport">
        <EditorMetaHeader v-if="meta" :meta="meta" :editable="editable" :word-count="wordCount" />
        <textarea
          ref="titleEl"
          v-show="titleVisible"
          class="moodiary-title"
          rows="1"
          :readonly="!editable"
          :placeholder="editable ? t('titlePlaceholder') : ''"
          @input="onTitleInput"
          @compositionstart="onTitleCompositionStart"
          @compositionend="onTitleCompositionEnd"
          @keydown="onTitleKeydown"
          @focus="onTitleFocus"
          @blur="onTitleBlur"
        ></textarea>
        <EditorContent :editor="editor" class="moodiary-editor" />
        <EditorLinksPanel v-if="showLinks && links" :links="links" />
      </div>
    </div>
    <EditorSearchBar v-if="platform === 'mobile'" :platform="platform" />
    <UndoToast />
    <EditorToolbar
      v-if="editor && showToolbar && platform === 'mobile'"
      :editor="editor"
      :platform="platform"
      @pick="pick"
    />
    <BlockMenu v-if="editor && editable" :editor="editor" />
  </div>
</template>
