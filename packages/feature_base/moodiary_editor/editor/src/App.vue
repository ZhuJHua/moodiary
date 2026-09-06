<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import MoodiaryEditor from './components/MoodiaryEditor.vue'
import DiaryLinkSuggestion from './components/DiaryLinkSuggestion.vue'
import { installBridge } from './bridge'
import { readBoot } from './bridge/boot'
import { applyTheme, setFontBase } from './bridge/theme'
import { setSaveStatus } from './bridge/save-status'
import { post } from './bridge/post'
import {
  setAudioDefaultName,
  setMediaInfoPrefix,
  setMediaPrefix,
  unproxyMedia,
} from './editor/media'

const boot = readBoot()
if (boot.mediaBase) setMediaPrefix(boot.mediaBase)
if (boot.mediaInfoBase) setMediaInfoPrefix(boot.mediaInfoBase)
if (boot.audioDefaultName) setAudioDefaultName(boot.audioDefaultName)
// 字体文件基址须先于 applyTheme 注入：applyTheme 里用它拼 @font-face 的 src。
if (boot.fontBase) setFontBase(boot.fontBase)
const initialEditable = boot.editable ?? true
const placeholder = boot.placeholder ?? ''
const titlePlaceholder = boot.titlePlaceholder ?? ''
const platform = boot.platform ?? 'desktop'

installBridge()
if (boot.theme) applyTheme(boot.theme)
if (boot.saveStatus) setSaveStatus(boot.saveStatus)

const shell = ref<HTMLElement>()

function onClick(e: MouseEvent): void {
  const target = e.target as HTMLElement | null
  const link = target?.closest('[data-type="diaryLink"]') as HTMLElement | null
  if (link) {
    const id = link.getAttribute('data-id')
    if (id) {
      e.preventDefault()
      post('linkTap', { id })
    }
    return
  }
  const img = target?.closest('img')
  if (!img) return
  const src = (img as HTMLImageElement).getAttribute('src')
  if (!src || src.startsWith('data:')) return
  e.preventDefault()
  const all = (
    Array.from(shell.value?.querySelectorAll('.ProseMirror img') ?? []) as HTMLImageElement[]
  ).filter((el) => {
    const s = el.getAttribute('src')
    return s && !s.startsWith('data:')
  })
  const srcs = all.map((el) => unproxyMedia(el.getAttribute('src') as string))
  const index = all.indexOf(img as HTMLImageElement)
  post('imageTap', { src: unproxyMedia(src), srcs, index: index < 0 ? 0 : index })
}

onMounted(() => shell.value?.addEventListener('click', onClick))
onBeforeUnmount(() => shell.value?.removeEventListener('click', onClick))
</script>

<template>
  <div ref="shell" class="editor-shell">
    <MoodiaryEditor
      :editable="initialEditable"
      :placeholder="placeholder"
      :title-placeholder="titlePlaceholder"
      :platform="platform"
    />
    <DiaryLinkSuggestion />
  </div>
</template>
