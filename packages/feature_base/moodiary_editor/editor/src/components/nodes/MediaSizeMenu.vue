<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import IconAspectRatio from '~icons/lucide/ratio'
import PopupMenu from '../PopupMenu.vue'
import {
  MIN_WIDTH_PERCENT,
  WIDTH_PERCENT_STOPS,
  snapWidthPercent,
} from '../../editor/media-size'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  modelValue: number | null
  title: string
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: number | null): void
  (e: 'preview', value: number | null): void
}>()

const { t } = useI18n()

const menuOpen = ref(false)
const draft = ref<number | null>(null)

const shown = computed(() => draft.value ?? props.modelValue)
const sliderValue = computed(() => shown.value ?? 100)
const readout = computed(() =>
  shown.value === null ? t('mediaSize.defaultWidth') : `${shown.value}%`,
)

function setDraft(value: number | null): void {
  draft.value = value
  emit('preview', value)
}

function commit(value: number | null): void {
  setDraft(null)
  emit('update:modelValue', value)
}

function onSlide(e: Event): void {
  setDraft(snapWidthPercent(Number((e.target as HTMLInputElement).value)))
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
  <PopupMenu v-model="menuOpen" class="moodiary-size__menu">
    <template #trigger>
      <button class="moodiary-size__badge" type="button" :title="title" @mousedown.prevent>
        <span class="moodiary-size__chip"><IconAspectRatio class="size-[18px]" /></span>
      </button>
    </template>

    <template #panel>
      <div class="moodiary-size__panel flex w-52 flex-col px-2 py-1">
        <div class="flex items-baseline justify-between">
          <span class="text-xs opacity-70">{{ t('mediaSize.width') }}</span>
          <span class="text-sm font-medium tabular-nums">{{ readout }}</span>
        </div>

        <input
          class="range range-primary range-xs mt-1"
          type="range"
          :min="MIN_WIDTH_PERCENT"
          max="100"
          step="1"
          :value="sliderValue"
          :aria-label="t('mediaSize.width')"
          @input="onSlide"
          @change="onSlideEnd"
        />

        <!-- min 取 25 使四档正好四等分 -->
        <div class="mt-1 flex justify-between px-2.5 text-[10px] opacity-50">
          <span v-for="stop in WIDTH_PERCENT_STOPS" :key="`tick-${stop}`">|</span>
        </div>
        <div class="flex justify-between px-1 text-[10px]">
          <button
            v-for="stop in WIDTH_PERCENT_STOPS"
            :key="stop"
            class="moodiary-size__stop"
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
          :disabled="modelValue === null && draft === null"
          @mousedown.prevent
          @click="commit(null)"
        >
          {{ t('mediaSize.reset') }}
        </button>
      </div>
    </template>
  </PopupMenu>
</template>
