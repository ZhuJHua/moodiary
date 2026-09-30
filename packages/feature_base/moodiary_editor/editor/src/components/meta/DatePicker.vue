<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import IconChevronLeft from '~icons/lucide/chevron-left'
import IconChevronRight from '~icons/lucide/chevron-right'
import IconChevronDown from '~icons/lucide/chevron-down'
import Popover from '../ui/Popover.vue'
import { post } from '../../bridge/post'
import type { EditorMeta } from '../../bridge/meta'
import { dateLocale } from '../../i18n'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  meta: EditorMeta
}>()

const { t } = useI18n()

interface Ymd {
  y: number
  m: number
  d: number
}

const pop = ref<InstanceType<typeof Popover>>()
const yearList = ref<HTMLElement>()
const mode = ref<'day' | 'year'>('day')
const viewYear = ref(2000)
const viewMonth = ref(0)

const parse = (iso: string | undefined): Ymd | null => {
  const m = iso ? /^(\d{4})-(\d{2})-(\d{2})/.exec(iso) : null
  return m ? { y: Number(m[1]), m: Number(m[2]) - 1, d: Number(m[3]) } : null
}
const key = (v: Ymd): number => v.y * 10000 + v.m * 100 + v.d

const selected = computed(() => parse(props.meta.time))
const minDate = computed<Ymd>(() => parse(props.meta.minDate) ?? { y: 1949, m: 9, d: 1 })
const today = ref<Ymd>({ y: 2000, m: 0, d: 1 })

const monthTitle = computed(() =>
  new Intl.DateTimeFormat(dateLocale(), { year: 'numeric', month: 'long' }).format(
    new Date(viewYear.value, viewMonth.value, 1),
  ),
)

const weekdays = computed(() => {
  const fmt = new Intl.DateTimeFormat(dateLocale(), { weekday: 'narrow' })
  const first = props.meta.firstDayOfWeek ?? 0
  return Array.from({ length: 7 }, (_, i) => fmt.format(new Date(2024, 0, 7 + ((first + i) % 7))))
})

const cells = computed(() => {
  const first = props.meta.firstDayOfWeek ?? 0
  const lead = (new Date(viewYear.value, viewMonth.value, 1).getDay() - first + 7) % 7
  const days = new Date(viewYear.value, viewMonth.value + 1, 0).getDate()
  const out: Array<Ymd | null> = Array.from({ length: lead }, () => null)
  for (let d = 1; d <= days; d++) out.push({ y: viewYear.value, m: viewMonth.value, d })
  return out
})

const years = computed(() => {
  const out: number[] = []
  for (let y = minDate.value.y; y <= today.value.y; y++) out.push(y)
  return out
})

const monthKey = (y: number, m: number): number => y * 12 + m
const canPrev = computed(
  () => monthKey(viewYear.value, viewMonth.value) > monthKey(minDate.value.y, minDate.value.m),
)
const canNext = computed(
  () => monthKey(viewYear.value, viewMonth.value) < monthKey(today.value.y, today.value.m),
)

const disabled = (v: Ymd): boolean => key(v) < key(minDate.value) || key(v) > key(today.value)
const isSelected = (v: Ymd): boolean => !!selected.value && key(v) === key(selected.value)
const isToday = (v: Ymd): boolean => key(v) === key(today.value)

function shiftMonth(delta: number): void {
  const k = monthKey(viewYear.value, viewMonth.value) + delta
  viewYear.value = Math.floor(k / 12)
  viewMonth.value = k % 12
}

function clampView(): void {
  const k = Math.min(
    Math.max(monthKey(viewYear.value, viewMonth.value), monthKey(minDate.value.y, minDate.value.m)),
    monthKey(today.value.y, today.value.m),
  )
  viewYear.value = Math.floor(k / 12)
  viewMonth.value = k % 12
}

function showYears(): void {
  mode.value = 'year'
  void nextTick(() => {
    yearList.value
      ?.querySelector<HTMLElement>('[aria-current="true"]')
      ?.scrollIntoView({ block: 'center' })
  })
}

function pickYear(y: number): void {
  viewYear.value = y
  clampView()
  mode.value = 'day'
}

function pick(v: Ymd): void {
  pop.value?.close()
  if (!isSelected(v)) post('changeDate', { year: v.y, month: v.m + 1, day: v.d })
}

function open(anchor: HTMLElement): void {
  const now = new Date()
  today.value = { y: now.getFullYear(), m: now.getMonth(), d: now.getDate() }
  const start = selected.value ?? today.value
  viewYear.value = start.y
  viewMonth.value = start.m
  clampView()
  mode.value = 'day'
  pop.value?.open(anchor)
}

defineExpose({ open })
</script>

<template>
  <Popover ref="pop" panel-class="w-[300px]" :label="t('meta.date')">
    <div class="flex items-center justify-between">
      <button
        type="button"
        class="moodiary-pop-item w-auto gap-1 px-2.5 font-semibold"
        @click="mode === 'day' ? showYears() : (mode = 'day')"
      >
        {{ monthTitle }}
        <IconChevronDown class="size-4 opacity-70 transition-transform" :class="{ 'rotate-180': mode === 'year' }" />
      </button>
      <div v-if="mode === 'day'" class="flex gap-0.5 pr-1">
        <button type="button" class="moodiary-pop-icon" :disabled="!canPrev" :aria-label="t('meta.prevMonth')" @click="shiftMonth(-1)">
          <IconChevronLeft />
        </button>
        <button type="button" class="moodiary-pop-icon" :disabled="!canNext" :aria-label="t('meta.nextMonth')" @click="shiftMonth(1)">
          <IconChevronRight />
        </button>
      </div>
    </div>

    <div v-if="mode === 'day'" class="grid grid-cols-7 gap-y-0.5 px-1 pb-1 text-center text-sm">
      <span v-for="(w, i) in weekdays" :key="`w-${i}`" class="py-1 text-xs opacity-60">{{ w }}</span>
      <template v-for="(c, i) in cells" :key="`c-${i}`">
        <span v-if="!c"></span>
        <button
          v-else
          type="button"
          class="moodiary-pop-icon mx-auto size-9 tabular-nums"
          :class="{ 'is-active': isSelected(c), 'is-today': isToday(c) }"
          :disabled="disabled(c)"
          :aria-pressed="isSelected(c)"
          @click="pick(c)"
        >
          {{ c.d }}
        </button>
      </template>
    </div>

    <div v-else ref="yearList" class="grid max-h-64 grid-cols-4 gap-0.5 overflow-y-auto overscroll-contain">
      <button
        v-for="y in years"
        :key="y"
        type="button"
        class="moodiary-pop-item justify-center px-0 tabular-nums"
        :class="{ 'is-active': y === viewYear }"
        :aria-current="y === viewYear"
        @click="pickYear(y)"
      >
        {{ y }}
      </button>
    </div>
  </Popover>
</template>
