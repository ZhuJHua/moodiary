<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import Popover from '../ui/Popover.vue'
import WheelColumn from '../ui/WheelColumn.vue'
import { post } from '../../bridge/post'
import type { EditorMeta } from '../../bridge/meta'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  meta: EditorMeta
}>()

const { t } = useI18n()

const pop = ref<InstanceType<typeof Popover>>()
const period = ref<InstanceType<typeof WheelColumn>>()
const hour = ref<InstanceType<typeof WheelColumn>>()
const minute = ref<InstanceType<typeof WheelColumn>>()

const use24h = computed(() => props.meta.use24h !== false)
const pad = (n: number): string => String(n).padStart(2, '0')
const hours = computed(() =>
  use24h.value
    ? Array.from({ length: 24 }, (_, i) => pad(i))
    : Array.from({ length: 12 }, (_, i) => String(i === 0 ? 12 : i)),
)
const minutes = Array.from({ length: 60 }, (_, i) => pad(i))
const periods = computed(() => [t('meta.am'), t('meta.pm')])

function initial(): { h: number; m: number } {
  const match = props.meta.time ? /T(\d{2}):(\d{2})/.exec(props.meta.time) : null
  return match ? { h: Number(match[1]), m: Number(match[2]) } : { h: 0, m: 0 }
}

async function open(anchor: HTMLElement): Promise<void> {
  pop.value?.open(anchor)
  await nextTick()
  const { h, m } = initial()
  if (use24h.value) {
    hour.value?.scrollTo(h)
  } else {
    period.value?.scrollTo(h >= 12 ? 1 : 0)
    hour.value?.scrollTo(h % 12)
  }
  minute.value?.scrollTo(m)
}

function confirm(): void {
  const h = hour.value?.current() ?? 0
  const m = minute.value?.current() ?? 0
  const value = use24h.value ? h : h + ((period.value?.current() ?? 0) === 1 ? 12 : 0)
  pop.value?.close()
  const before = initial()
  if (value !== before.h || m !== before.m) post('changeTime', { hour: value, minute: m })
}

defineExpose({ open })
</script>

<template>
  <Popover ref="pop" panel-class="w-[264px]" :label="t('meta.time')">
    <div class="flex items-center justify-center gap-2 pt-1">
      <WheelColumn v-if="!use24h" ref="period" class="w-18" :items="periods" :label="t('meta.period')" />
      <WheelColumn ref="hour" class="w-18" :items="hours" :label="t('meta.hour')" />
      <span class="text-xl font-medium opacity-60">:</span>
      <WheelColumn ref="minute" class="w-18" :items="minutes" :label="t('meta.minute')" />
    </div>
    <div class="flex justify-end">
      <button type="button" class="moodiary-pop-item w-auto px-4 font-semibold text-primary" @click="confirm">
        {{ t('meta.confirm') }}
      </button>
    </div>
  </Popover>
</template>
