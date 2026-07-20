<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import MoodiaryEditor from './components/MoodiaryEditor.vue'
import DiaryLinkSuggestion from './components/DiaryLinkSuggestion.vue'
import { installBridge } from './bridge'
import { readBoot } from './bridge/boot'
import { applyTheme, setFontBase } from './bridge/theme'
import { setSaveStatus } from './bridge/save-status'
import { post } from './bridge/post'
import { setMediaPrefix, unproxyMedia } from './editor/media'

// Flutter 把引导数据挂在页面 URL 的 ?boot= 上（readBoot 同步解析，先于编辑器构建）。
// 初始内容不走 boot：ready 后由 Flutter setContent（见 moodiary_editor.dart）。
const boot = readBoot()
if (boot.mediaBase) setMediaPrefix(boot.mediaBase)
// 字体文件基址须先于 applyTheme 注入：applyTheme 里用它拼 @font-face 的 src。
if (boot.fontBase) setFontBase(boot.fontBase)
const initialEditable = boot.editable ?? true
const placeholder = boot.placeholder ?? ''
// 决定工具栏位置（桌面置顶 / 移动置底）。Flutter 始终下发 platform；缺省按桌面（顶部工具栏到处都合理）。
const platform = boot.platform ?? 'desktop'

installBridge()
if (boot.theme) applyTheme(boot.theme)
if (boot.saveStatus) setSaveStatus(boot.saveStatus)

const shell = ref<HTMLElement>()

// 点击：① 双链 chip → 上报 linkTap（Flutter 跳转目标日记）；② 正文图片 → imageTap（反解文件名）。
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
  // data: URI = 拖拽/粘贴上传落盘前的临时预览，落盘后 src 会换成文件名，此时不预览。
  if (!src || src.startsWith('data:')) return
  e.preventDefault()
  // 全文图片列表 + 被点下标，供 Flutter 原生画廊左右翻页。
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
      :platform="platform"
    />
    <DiaryLinkSuggestion />
  </div>
</template>
