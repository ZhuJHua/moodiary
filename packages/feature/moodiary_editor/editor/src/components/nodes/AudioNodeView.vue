<script setup lang="ts">
// 音频节点视图：webview 内播放，用原生 <audio>（HTMLMediaElement API）+ daisyUI 自绘控件（无播放器库）。
// 音频字节由本地回环服务按需供给（支持 HTTP Range）。控件：播放/暂停 + daisyUI range 进度条（自带
// 已播放填充）+ 时间 + 静音。图标用 unplugin-icons 按需引入 lucide。读模式下同样可播。
import { computed, ref } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import IconPlay from '~icons/lucide/play'
import IconPause from '~icons/lucide/pause'
import IconVolume from '~icons/lucide/volume-2'
import IconMuted from '~icons/lucide/volume-x'
import { mediaUrl } from '../../editor/media'
import { formatTime, useMediaControls } from '../../editor/use-media'

const props = defineProps(nodeViewProps)

const filename = computed(() => (props.node.attrs.filename as string | null) ?? '')
const src = computed(() => (filename.value ? mediaUrl(filename.value) : ''))

const audioEl = ref<HTMLAudioElement | null>(null)
const { playing, duration, muted, sliderValue, toggle, toggleMute, onSeekInput, onSeekChange } =
  useMediaControls(audioEl)
</script>

<template>
  <NodeViewWrapper
    class="moodiary-media moodiary-media--audio"
    :class="{ 'is-selected': selected }"
    contenteditable="false"
  >
    <div
      class="flex items-center gap-3 rounded-box border border-base-300 bg-base-200 px-3 py-2"
    >
      <button
        class="btn btn-circle btn-sm btn-primary shrink-0"
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
        aria-label="音频进度"
        @input="onSeekInput"
        @change="onSeekChange"
      />
      <span class="shrink-0 text-xs tabular-nums opacity-70">
        {{ formatTime(sliderValue) }} / {{ formatTime(duration) }}
      </span>
      <button
        class="btn btn-circle btn-ghost btn-xs shrink-0"
        type="button"
        :title="muted ? '取消静音' : '静音'"
        @click="toggleMute"
      >
        <component :is="muted ? IconMuted : IconVolume" class="size-5" />
      </button>
    </div>
    <audio ref="audioEl" :src="src" preload="metadata"></audio>
  </NodeViewWrapper>
</template>
