<script setup lang="ts">
import { ref } from 'vue'
import Popover from '../ui/Popover.vue'
import { post } from '../../bridge/post'
import type { EditorMeta } from '../../bridge/meta'
import { moodIcon } from './icons'
import { useI18n } from 'vue-i18n'

defineProps<{
  meta: EditorMeta
}>()

const { t } = useI18n()

const pop = ref<InstanceType<typeof Popover>>()

function select(mood: string): void {
  pop.value?.close()
  post('changeMood', { mood })
}

defineExpose({ open: (anchor: HTMLElement) => pop.value?.open(anchor) })
</script>

<template>
  <Popover ref="pop" panel-class="w-[276px]" :label="t('meta.mood')">
    <div class="grid grid-cols-4 gap-0.5">
      <button
        v-for="m in meta.moods"
        :key="m.value"
        type="button"
        class="moodiary-pop-cell"
        :class="{ 'is-active': m.value === meta.mood }"
        :style="m.value === meta.mood ? { color: m.color, background: `${m.color}26` } : undefined"
        :aria-pressed="m.value === meta.mood"
        @click="select(m.value)"
      >
        <component :is="moodIcon(m.icon)" />
        <span>{{ m.label }}</span>
      </button>
    </div>
  </Popover>
</template>
