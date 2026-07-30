<script setup lang="ts">
// 视频节点视图：webview 内播放，用原生 <video>（HTMLMediaElement API）+ daisyUI 自绘控件（无播放器库）。
// 视频字节由本地回环服务按需供给（支持 HTTP Range —— WKWebView 的 <video> 必须有 206 才能播）；海报
// 用同名 `?poster=1` 取 thumbnail jpeg。iOS 靠 playsinline 内联而非弹原生播放器。
// 图标用 unplugin-icons 按需引入 Material Symbols。
//
// **全屏不在 webview 内做**：Android 的 Element Fullscreen + webview_flutter 的 custom-view 回调、
// iOS 的 webkitEnterFullscreen（必然交给 AVKit、丢掉自绘控件）都接过一版，真机观感不过关，已撤除。
// 现在点全屏键 = 把播放**交接**给 Flutter 侧的原生播放器（照图片 imageTap 那条既成链路），
// 交接前必须先暂停本地播放，否则两个解码器同时出声。退出时 Flutter 会经 resumeVideo 回灌位置。
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import IconPlay from '~icons/material-symbols/play-arrow-rounded'
import IconPause from '~icons/material-symbols/pause-rounded'
import IconVolume from '~icons/material-symbols/volume-up-rounded'
import IconMuted from '~icons/material-symbols/volume-off-rounded'
import IconFullscreen from '~icons/material-symbols/fullscreen-rounded'
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
const { playing, duration, muted, sliderValue, toggle, toggleMute, onSeekInput, onSeekChange } =
  useMediaControls(videoEl)

// 容器比例夹在 [4:5, 16:9] 之间取片子自身的比例，画面 object-contain 居中，信箱区铺一层
// 高斯模糊的封面（不是黑色）。
//
// 为什么不是恒 16:9：9:16 的手机竖拍在 16:9 容器里，按高度撑满后画面只剩 114px 宽（360px 列），
// 两侧全是模糊边框，太小。夹到 4:5 后画面 253px 宽，而容器高度 450px 仍远小于「宽度满栏、
// 高度随比例」的 640px —— 竖拍不再吃掉整屏，也没缩成邮票。
// 比例落在区间内的片子（4:3 / 1:1 / 16:9…）直接用自身比例，画面正好铺满容器。
const MIN_FRAME_RATIO = 4 / 5
const MAX_FRAME_RATIO = 16 / 9

const ratio = ref<number | null>(null)
const frameRatio = computed(() =>
  ratio.value === null
    ? MAX_FRAME_RATIO
    : Math.min(MAX_FRAME_RATIO, Math.max(MIN_FRAME_RATIO, ratio.value)),
)

// 只在画面确实填不满容器（即比例被夹过）时才铺模糊层 —— 它会被提升成合成层，而铺满容器的
// 片子会把它整个盖住，纯属白烧。metadata 未到时先铺，那会儿也不知道比例，且同样看不见。
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

// —— 控制条自动隐藏 ——
// 触屏没有 hover，所以沿用移动端播放器的通用语汇：**点画面切控制条显隐**，播放/暂停交给按钮
// （原来点画面是播放/暂停 —— 那是桌面习惯，一旦控制条会自己藏起来，用户第一下点的意图必然是
// 「把它叫回来」）。暂停时不自动隐藏：没有控制条的暂停画面是个死胡同。
const CONTROLS_HIDE_DELAY = 3000

const controlsVisible = ref(true)
let hideTimer: ReturnType<typeof setTimeout> | undefined

function clearHideTimer(): void {
  if (hideTimer !== undefined) {
    clearTimeout(hideTimer)
    hideTimer = undefined
  }
}
/** 播放中才计时；任何交互都调它来续命。 */
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
    // 暂停态藏掉就没有任何操作入口了，故只在播放中允许点一下收起。
    if (playing.value) {
      controlsVisible.value = false
      clearHideTimer()
    }
    return
  }
  keepControls()
}

// 开始播放 → 开始计时；暂停 → 立刻显示并停表。
watch(playing, keepControls)

/** 交接给 Flutter 原生播放器。必须先暂停：两个解码器同时播就是两路声音。 */
function handOffToNative(): void {
  const el = videoEl.value
  if (!el || !filename.value) return
  try {
    el.pause()
  } catch {
    // no-op
  }
  keepControls()
  post('videoFullscreen', { name: filename.value, position: el.currentTime })
}

// 拖进度条可能超过 3 秒，单靠 pointerdown 续命会在拖拽中途被藏掉。
function onSeek(e: Event): void {
  onSeekInput(e)
  keepControls()
}
function onSeekDone(e: Event): void {
  onSeekChange(e)
  keepControls()
}

onMounted(() => {
  // iOS WKWebView 靠 playsinline 内联播放（否则一播就弹系统全屏播放器）；命令式设置避免依赖模板侧类型。
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
    <!-- position 走自家 CSS，不借 Tailwind 的 .relative —— 见 moodiary-editor.css 里的说明。 -->
    <div
      class="moodiary-video__frame moodiary-video__frame--boxed rounded-box overflow-hidden"
      :style="{ '--video-ratio': frameRatio }"
    >
      <!-- 信箱区填充：封面的高斯模糊版（竖拍 / 异比例视频的左右留白） -->
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

      <!-- 底部控制条：播放中 3 秒无操作淡出（pointer-events 一并关掉，点击穿到画面上） -->
      <div
        class="moodiary-video__bar absolute inset-x-0 bottom-0 flex items-center gap-2 bg-gradient-to-t from-black/70 to-transparent px-3 pb-2 pt-6 text-white"
        :class="{ 'is-hidden': !controlsVisible }"
        @pointerdown="keepControls"
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
          @input="onSeek"
          @change="onSeekDone"
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
          title="全屏播放"
          @click="handOffToNative"
        >
          <IconFullscreen class="size-5" />
        </button>
      </div>
    </div>
  </NodeViewWrapper>
</template>
