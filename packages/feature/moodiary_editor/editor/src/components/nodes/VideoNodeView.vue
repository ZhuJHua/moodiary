<script setup lang="ts">
// 视频节点视图：webview 内播放，用原生 <video>（HTMLMediaElement API）+ daisyUI 自绘控件（无播放器库）。
// 视频字节由本地回环服务按需供给（支持 HTTP Range —— WKWebView 的 <video> 必须有 206 才能播）；海报
// 用同名 `?poster=1` 取 thumbnail jpeg。全屏用 CSS 全窗（webview 内原生 Fullscreen API 不可靠）；iOS
// 靠 playsinline 内联而非弹原生播放器。图标用 unplugin-icons 按需引入 Material Symbols。
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import IconPlay from '~icons/material-symbols/play-arrow-rounded'
import IconPause from '~icons/material-symbols/pause-rounded'
import IconVolume from '~icons/material-symbols/volume-up-rounded'
import IconMuted from '~icons/material-symbols/volume-off-rounded'
import IconFullscreen from '~icons/material-symbols/fullscreen-rounded'
import IconFullscreenExit from '~icons/material-symbols/fullscreen-exit-rounded'
import { mediaUrl } from '../../editor/media'
import { formatTime, useMediaControls } from '../../editor/use-media'

const props = defineProps(nodeViewProps)

const filename = computed(() => (props.node.attrs.filename as string | null) ?? '')
const src = computed(() => (filename.value ? mediaUrl(filename.value) : ''))
const poster = computed(() =>
  filename.value ? mediaUrl(filename.value, { poster: true }) : '',
)

const videoEl = ref<HTMLVideoElement | null>(null)
const { playing, duration, muted, sliderValue, toggle, toggleMute, onSeekInput, onSeekChange } =
  useMediaControls(videoEl)

const fullscreen = ref(false)
function toggleFullscreen(): void {
  fullscreen.value = !fullscreen.value
}
function onKeydown(e: KeyboardEvent): void {
  if (e.key === 'Escape' && fullscreen.value) fullscreen.value = false
}

onMounted(() => {
  // iOS WKWebView 靠 playsinline 内联播放（否则弹原生全屏播放器）；命令式设置避免依赖模板侧类型。
  const el = videoEl.value
  if (el) {
    el.setAttribute('playsinline', '')
    el.setAttribute('webkit-playsinline', '')
  }
  window.addEventListener('keydown', onKeydown)
})
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown))
</script>

<template>
  <NodeViewWrapper
    class="moodiary-media moodiary-media--video"
    :class="{ 'is-selected': selected }"
    contenteditable="false"
  >
    <div
      class="moodiary-video__frame relative overflow-hidden bg-black"
      :class="
        fullscreen
          ? 'fixed inset-0 z-[60] flex items-center justify-center'
          : 'rounded-box'
      "
    >
      <video
        ref="videoEl"
        class="block w-full"
        :class="fullscreen ? 'h-full max-h-full object-contain' : ''"
        :src="src"
        :poster="poster"
        preload="metadata"
        @click="toggle"
      ></video>

      <!-- 暂停时居中大播放键 -->
      <button
        v-if="!playing"
        class="btn btn-circle btn-lg btn-primary absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
        type="button"
        title="播放"
        @click="toggle"
      >
        <IconPlay class="size-7" />
      </button>

      <!-- 底部控制条 -->
      <div
        class="absolute inset-x-0 bottom-0 flex items-center gap-2 bg-gradient-to-t from-black/70 to-transparent px-3 pb-2 pt-6 text-white"
      >
        <button
          class="btn btn-circle btn-ghost btn-xs text-white"
          type="button"
          :title="playing ? '暂停' : '播放'"
          @click="toggle"
        >
          <component :is="playing ? IconPause : IconPlay" class="size-5" />
        </button>
        <input
          class="range range-primary range-xs flex-1"
          type="range"
          min="0"
          :max="duration || 0"
          step="any"
          :value="sliderValue"
          aria-label="视频进度"
          @input="onSeekInput"
          @change="onSeekChange"
        />
        <span class="shrink-0 text-xs tabular-nums">
          {{ formatTime(sliderValue) }} / {{ formatTime(duration) }}
        </span>
        <button
          class="btn btn-circle btn-ghost btn-xs text-white"
          type="button"
          :title="muted ? '取消静音' : '静音'"
          @click="toggleMute"
        >
          <component :is="muted ? IconMuted : IconVolume" class="size-5" />
        </button>
        <button
          class="btn btn-circle btn-ghost btn-xs text-white"
          type="button"
          :title="fullscreen ? '退出全屏' : '全屏'"
          @click="toggleFullscreen"
        >
          <component :is="fullscreen ? IconFullscreenExit : IconFullscreen" class="size-5" />
        </button>
      </div>
    </div>
  </NodeViewWrapper>
</template>
