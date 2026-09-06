<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import IconAspectRatio from '~icons/lucide/ratio'
import PopupMenu from '../PopupMenu.vue'
import { editable } from '../../editor/editable'
import {
  IMAGE_SIZE_STOPS,
  MIN_IMAGE_PERCENT,
  snapWidthPercent,
} from '../../editor/image-node'
import { displaySrc } from '../../editor/media'

const props = defineProps(nodeViewProps)

const menuOpen = ref(false)
const draft = ref<number | null>(null)

const src = computed(() => {
  const raw = props.node.attrs.src
  return typeof raw === 'string' ? displaySrc(raw) : ''
})
const alt = computed(() => (props.node.attrs.alt as string | null) ?? '')
const title = computed(() => (props.node.attrs.title as string | null) ?? undefined)

const widthPercent = computed(() => {
  const v = props.node.attrs.widthPercent
  return typeof v === 'number' ? v : null
})
const shown = computed(() => draft.value ?? widthPercent.value)

const wrapperStyle = computed(() =>
  shown.value === null ? undefined : { maxWidth: `${shown.value}%` },
)
const sliderValue = computed(() => shown.value ?? 100)
const readout = computed(() => (shown.value === null ? '默认' : `${shown.value}%`))

function commit(value: number | null): void {
  draft.value = null
  props.updateAttributes({ widthPercent: value })
}

function onSlide(e: Event): void {
  draft.value = snapWidthPercent(Number((e.target as HTMLInputElement).value))
}
function onSlideEnd(e: Event): void {
  commit(snapWidthPercent(Number((e.target as HTMLInputElement).value)))
}

// 个别 WebView 的 range 不发 change 事件
watch(menuOpen, (open) => {
  if (!open && draft.value !== null) commit(draft.value)
})
</script>

<template>
  <NodeViewWrapper
    class="moodiary-image"
    :class="{ 'is-selected': selected }"
    :style="wrapperStyle"
    contenteditable="false"
  >
    <img class="moodiary-image__img" :src="src" :alt="alt" :title="title" draggable="false" />
    <PopupMenu v-if="editable" v-model="menuOpen" class="moodiary-image__menu">
      <template #trigger>
        <button class="moodiary-image__badge" type="button" title="图片尺寸" @mousedown.prevent>
          <span class="moodiary-image__chip"><IconAspectRatio class="size-[18px]" /></span>
        </button>
      </template>

      <template #panel>
        <div class="moodiary-image__panel flex w-52 flex-col px-2 py-1">
          <div class="flex items-baseline justify-between">
            <span class="text-xs opacity-70">宽度</span>
            <span class="text-sm font-medium tabular-nums">{{ readout }}</span>
          </div>

          <input
            class="range range-primary range-xs mt-1"
            type="range"
            :min="MIN_IMAGE_PERCENT"
            max="100"
            step="1"
            :value="sliderValue"
            aria-label="图片宽度"
            @input="onSlide"
            @change="onSlideEnd"
          />

          <!-- min 取 25 使四档正好四等分 -->
          <div class="mt-1 flex justify-between px-2.5 text-[10px] opacity-50">
            <span v-for="stop in IMAGE_SIZE_STOPS" :key="`tick-${stop}`">|</span>
          </div>
          <div class="flex justify-between px-1 text-[10px]">
            <button
              v-for="stop in IMAGE_SIZE_STOPS"
              :key="stop"
              class="moodiary-image__stop"
              :class="{ 'is-active': shown === stop }"
              type="button"
              @mousedown.prevent
              @click="commit(stop)"
            >
              {{ stop }}
            </button>
          </div>

          <button
            class="btn btn-ghost btn-xs mt-1"
            type="button"
            :disabled="widthPercent === null && draft === null"
            @mousedown.prevent
            @click="commit(null)"
          >
            恢复默认
          </button>
        </div>
      </template>
    </PopupMenu>
  </NodeViewWrapper>
</template>
