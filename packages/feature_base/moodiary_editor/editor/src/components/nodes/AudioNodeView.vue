<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import IconPlay from '~icons/lucide/play'
import IconPause from '~icons/lucide/pause'
import IconVolume from '~icons/lucide/volume-2'
import IconMuted from '~icons/lucide/volume-x'
import { audioDefaultName, fetchMediaName, mediaUrl } from '../../editor/media'
import { formatTime, useMediaControls } from '../../editor/use-media'

const props = defineProps(nodeViewProps)

const filename = computed(() => (props.node.attrs.filename as string | null) ?? '')
const src = computed(() => (filename.value ? mediaUrl(filename.value) : ''))

const displayName = ref(audioDefaultName())
onMounted(async () => {
  if (!filename.value) return
  const name = await fetchMediaName(filename.value)
  if (name) displayName.value = name
})

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
      class="flex items-center gap-3 rounded-box border border-base-300 bg-base-200 px-3 py-2.5"
    >
      <button
        class="btn btn-circle btn-sm btn-primary shrink-0"
        type="button"
        :title="playing ? '暂停' : '播放'"
        @click="toggle"
      >
        <component :is="playing ? IconPause : IconPlay" class="size-5" />
      </button>
      <div class="flex min-w-0 flex-1 flex-col gap-1">
        <div class="flex items-center gap-2">
          <span class="min-w-0 flex-1 truncate text-sm font-medium">{{ displayName }}</span>
          <button
            class="btn btn-circle btn-ghost btn-xs shrink-0"
            type="button"
            :title="muted ? '取消静音' : '静音'"
            @click="toggleMute"
          >
            <component :is="muted ? IconMuted : IconVolume" class="size-4" />
          </button>
        </div>
        <div class="flex items-center gap-2">
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
        </div>
      </div>
    </div>
    <audio ref="audioEl" :src="src" preload="metadata"></audio>
  </NodeViewWrapper>
</template>
