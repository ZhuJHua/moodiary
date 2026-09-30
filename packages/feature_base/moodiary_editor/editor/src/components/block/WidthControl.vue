<script setup lang="ts">
import { computed, ref } from 'vue'
import { MIN_WIDTH_PERCENT, WIDTH_PERCENT_STOPS, snapWidthPercent } from '../../editor/media-size'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  modelValue: number | null
}>()

const emit = defineEmits<{
  (e: 'preview', value: number | null): void
  (e: 'commit', value: number | null): void
}>()

const { t } = useI18n()

const draft = ref<number | null>(null)

const shown = computed(() => draft.value ?? props.modelValue)
const value = computed(() => shown.value ?? 100)
const readout = computed(() =>
  shown.value === null ? t('mediaSize.defaultWidth') : `${shown.value}%`,
)

const fraction = (v: number): string =>
  `${((v - MIN_WIDTH_PERCENT) / (100 - MIN_WIDTH_PERCENT)) * 100}%`

function setDraft(next: number | null): void {
  draft.value = next
  emit('preview', next)
}

function commit(next: number | null): void {
  setDraft(null)
  emit('commit', next)
}

const read = (e: Event): number => snapWidthPercent(Number((e.target as HTMLInputElement).value))
function onSlide(e: Event): void {
  setDraft(read(e))
}
function onSlideEnd(e: Event): void {
  commit(read(e))
}
// 拖动中松手在 range 外时个别 WebView 不发 change
function onPointerUp(): void {
  if (draft.value !== null) commit(draft.value)
}
</script>

<template>
  <div class="flex flex-col px-1 pt-1">
    <div class="flex items-baseline justify-between px-2.5">
      <span class="text-xs opacity-70">{{ t('mediaSize.width') }}</span>
      <span class="text-sm font-medium tabular-nums">{{ readout }}</span>
    </div>

    <input
      class="range range-primary range-xs mx-2.5 my-2 w-auto"
      type="range"
      :min="MIN_WIDTH_PERCENT"
      max="100"
      step="1"
      :value="value"
      tabindex="-1"
      :aria-label="t('mediaSize.width')"
      @mousedown.prevent
      @input="onSlide"
      @change="onSlideEnd"
      @pointerup="onPointerUp"
      @pointercancel="onPointerUp"
    />

    <div class="moodiary-width__stops">
      <button
        v-for="stop in WIDTH_PERCENT_STOPS"
        :key="stop"
        type="button"
        class="moodiary-width__stop"
        :class="{ 'is-active': shown === stop }"
        :style="{ left: fraction(stop) }"
        @click="commit(stop)"
      >
        {{ stop }}
      </button>
    </div>

    <button
      type="button"
      class="moodiary-pop-item is-dim mt-0.5 justify-center"
      :disabled="modelValue === null && draft === null"
      @click="commit(null)"
    >
      {{ t('mediaSize.reset') }}
    </button>
  </div>
</template>
