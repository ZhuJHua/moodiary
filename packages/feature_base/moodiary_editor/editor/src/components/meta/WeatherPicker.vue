<script setup lang="ts">
import { ref } from 'vue'
import IconRefresh from '~icons/lucide/refresh-cw'
import IconX from '~icons/lucide/x'
import Popover from '../ui/Popover.vue'
import { post } from '../../bridge/post'
import type { EditorMeta } from '../../bridge/meta'
import { weatherGlyph } from './icons'
import { useI18n } from 'vue-i18n'

defineProps<{
  meta: EditorMeta
}>()

const { t } = useI18n()

const pop = ref<InstanceType<typeof Popover>>()

function act(type: string, payload?: unknown): void {
  pop.value?.close()
  post(type, payload)
}

defineExpose({ open: (anchor: HTMLElement) => pop.value?.open(anchor) })
</script>

<template>
  <Popover ref="pop" panel-class="w-[276px]" :label="t('meta.weather')">
    <div class="grid grid-cols-4 gap-0.5">
      <button
        v-for="w in meta.weatherOptions"
        :key="w.code"
        type="button"
        class="moodiary-pop-cell"
        :class="{ 'is-active': w.code === meta.weather?.icon }"
        :aria-pressed="w.code === meta.weather?.icon"
        @click="act('changeWeather', { code: w.code })"
      >
        <span class="moodiary-qi">{{ weatherGlyph(w.code) }}</span>
        <span>{{ w.label }}</span>
      </button>
    </div>
    <template v-if="meta.weatherAutoLabel || meta.weather">
      <div class="moodiary-pop-divider"></div>
      <button v-if="meta.weatherAutoLabel" type="button" class="moodiary-pop-item" @click="act('fetchWeather')">
        <IconRefresh />{{ meta.weatherAutoLabel }}
      </button>
      <button v-if="meta.weather" type="button" class="moodiary-pop-item is-dim" @click="act('clearWeather')">
        <IconX />{{ meta.weatherClearLabel }}
      </button>
    </template>
  </Popover>
</template>
