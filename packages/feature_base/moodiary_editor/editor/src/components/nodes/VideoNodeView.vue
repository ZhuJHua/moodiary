<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import IconPlay from '~icons/lucide/play'
import IconPause from '~icons/lucide/pause'
import IconVolume from '~icons/lucide/volume-2'
import IconMuted from '~icons/lucide/volume-x'
import IconFullscreen from '~icons/lucide/maximize'
import { post } from '../../bridge/post'
import { mediaUrl } from '../../editor/media'
import { formatTime, useMediaControls } from '../../editor/use-media'

const props = defineProps(nodeViewProps)

const filename = computed(() => (props.node.attrs.filename as string | null) ?? '')
const src = computed(() => (filename.value ? mediaUrl(filename.value) : ''))
const poster = computed(() =>
  filename.value ? mediaUrl(filename.value, { poster: true }) : '',
)

const videoEl = ref<HTMLVideoElement | null>(null)
const { playing, duration, muted, sliderValue, dragging, toggle, toggleMute, seekTo, endSeek } =
  useMediaControls(videoEl)

const MIN_FRAME_RATIO = 4 / 5
const MAX_FRAME_RATIO = 16 / 9

const ratio = ref<number | null>(null)
const frameRatio = computed(() =>
  ratio.value === null
    ? MAX_FRAME_RATIO
    : Math.min(MAX_FRAME_RATIO, Math.max(MIN_FRAME_RATIO, ratio.value)),
)

const showBackdrop = computed(
  () =>
    poster.value !== '' &&
    (ratio.value === null || Math.abs(ratio.value - frameRatio.value) > 0.02),
)
function onLoadedMetadata(): void {
  const el = videoEl.value
  if (el && el.videoWidth > 0 && el.videoHeight > 0) {
    ratio.value = el.videoWidth / el.videoHeight
  }
}

const CONTROLS_HIDE_DELAY = 3000

const controlsVisible = ref(true)
let hideTimer: ReturnType<typeof setTimeout> | undefined

function clearHideTimer(): void {
  if (hideTimer !== undefined) {
    clearTimeout(hideTimer)
    hideTimer = undefined
  }
}
function keepControls(): void {
  controlsVisible.value = true
  clearHideTimer()
  if (playing.value) {
    hideTimer = setTimeout(() => {
      controlsVisible.value = false
    }, CONTROLS_HIDE_DELAY)
  }
}
function onPictureTap(): void {
  if (controlsVisible.value) {
    if (playing.value) {
      controlsVisible.value = false
      clearHideTimer()
    }
    return
  }
  keepControls()
}

watch(playing, keepControls)

function handOffToNative(): void {
  const el = videoEl.value
  if (!el || !filename.value) return
  try {
    el.pause()
  } catch {
  }
  keepControls()
  post('videoFullscreen', { name: filename.value, position: el.currentTime })
}

const trackEl = ref<HTMLElement | null>(null)

const progressPercent = computed(() => {
  const total = duration.value
  if (!(total > 0)) return 0
  return Math.min(100, Math.max(0, (sliderValue.value / total) * 100))
})

function timeAtPointer(e: PointerEvent): number | null {
  const el = trackEl.value
  const total = duration.value
  if (!el || !(total > 0)) return null
  const rect = el.getBoundingClientRect()
  if (rect.width <= 0) return null
  const fraction = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width))
  return fraction * total
}

function onTrackDown(e: PointerEvent): void {
  const at = timeAtPointer(e)
  if (at === null) return
  // 老 WebView / jsdom 可能没有 setPointerCapture
  try {
    trackEl.value?.setPointerCapture?.(e.pointerId)
  } catch {
  }
  seekTo(at)
  keepControls()
}
function onTrackMove(e: PointerEvent): void {
  if (!dragging.value) return
  const at = timeAtPointer(e)
  if (at === null) return
  seekTo(at)
  keepControls()
}
function onTrackUp(e: PointerEvent): void {
  if (!dragging.value) return
  endSeek(timeAtPointer(e) ?? sliderValue.value)
  keepControls()
}

onMounted(() => {
  // iOS WKWebView 需要 playsinline 才能内联播放，否则弹系统全屏播放器
  const el = videoEl.value
  if (el) {
    el.setAttribute('playsinline', '')
    el.setAttribute('webkit-playsinline', '')
    el.addEventListener('loadedmetadata', onLoadedMetadata)
    onLoadedMetadata()
  }
})
onBeforeUnmount(() => {
  clearHideTimer()
  videoEl.value?.removeEventListener('loadedmetadata', onLoadedMetadata)
})
</script>

<template>
  <NodeViewWrapper
    class="moodiary-media moodiary-media--video"
    :class="{ 'is-selected': selected }"
    contenteditable="false"
  >
    <div
      class="moodiary-video__frame moodiary-video__frame--boxed rounded-box overflow-hidden"
      :style="{ '--video-ratio': frameRatio }"
    >
      <div
        v-if="showBackdrop"
        class="moodiary-video__backdrop"
        :style="{ backgroundImage: `url(${poster})` }"
      ></div>

      <video
        ref="videoEl"
        class="moodiary-video__el"
        :src="src"
        :poster="poster"
        preload="metadata"
        @click="onPictureTap"
      ></video>

      <div
        class="moodiary-video__bar absolute inset-x-0 bottom-0 flex items-center gap-1"
        :class="{ 'is-hidden': !controlsVisible, 'is-scrubbing': dragging }"
        @pointerdown="keepControls"
      >
        <button
          class="moodiary-video__key"
          type="button"
          :title="playing ? '暂停' : '播放'"
          @click="toggle"
        >
          <component :is="playing ? IconPause : IconPlay" class="size-5" />
        </button>

        <div
          ref="trackEl"
          class="moodiary-video__track"
          :class="{ 'is-pressed': dragging }"
          role="slider"
          aria-label="视频进度"
          :aria-valuemin="0"
          :aria-valuemax="Math.round(duration)"
          :aria-valuenow="Math.round(sliderValue)"
          :aria-valuetext="`${formatTime(sliderValue)} / ${formatTime(duration)}`"
          @pointerdown="onTrackDown"
          @pointermove="onTrackMove"
          @pointerup="onTrackUp"
          @pointercancel="onTrackUp"
        >
          <span class="moodiary-video__rail"></span>
          <span class="moodiary-video__fill" :style="{ width: `${progressPercent}%` }"></span>
          <span class="moodiary-video__thumb" :style="{ left: `${progressPercent}%` }"></span>
        </div>

        <span class="moodiary-video__time">
          <span class="moodiary-video__time-pos">{{ formatTime(sliderValue) }}</span>
          <span class="moodiary-video__time-sep">/</span>
          <span class="moodiary-video__time-dur">{{ formatTime(duration) }}</span>
        </span>

        <button
          class="moodiary-video__key"
          type="button"
          :title="muted ? '取消静音' : '静音'"
          @click="toggleMute"
        >
          <component :is="muted ? IconMuted : IconVolume" class="size-5" />
        </button>
        <button
          class="moodiary-video__key"
          type="button"
          title="全屏播放"
          @click="handOffToNative"
        >
          <IconFullscreen class="size-5" />
        </button>
      </div>
    </div>
  </NodeViewWrapper>
</template>
