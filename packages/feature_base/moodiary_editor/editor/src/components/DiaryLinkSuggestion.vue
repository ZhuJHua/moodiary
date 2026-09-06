<script setup lang="ts">
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  reactive,
  ref,
  watch,
  type CSSProperties,
} from 'vue'
import { linkSuggestion, selectCandidate } from '../editor/diary-link'

const box = ref<HTMLElement | null>(null)
const pos = reactive<{
  left: number
  top: number | null
  bottom: number | null
  maxH: number
  ready: boolean
}>({ left: 0, top: 0, bottom: null, maxH: 240, ready: false })

const MARGIN = 8
const GAP = 4
const HARD_MAX = 320

function place(): void {
  const r = linkSuggestion.rect
  const el = box.value
  if (!r || !el) return
  const vw = window.innerWidth
  const vh = window.innerHeight
  const w = el.offsetWidth
  const h = el.offsetHeight

  let left = r.left
  if (left + w > vw - MARGIN) left = vw - w - MARGIN
  if (left < MARGIN) left = MARGIN

  const belowSpace = vh - r.bottom - GAP - MARGIN
  const aboveSpace = r.top - GAP - MARGIN

  if (h <= belowSpace || belowSpace >= aboveSpace) {
    pos.top = Math.round(r.bottom + GAP)
    pos.bottom = null
    pos.maxH = Math.max(120, Math.min(HARD_MAX, belowSpace))
  } else {
    pos.top = null
    pos.bottom = Math.round(vh - (r.top - GAP))
    pos.maxH = Math.max(120, Math.min(HARD_MAX, aboveSpace))
  }
  pos.left = Math.round(left)
  pos.ready = true
}

watch(
  () => [
    linkSuggestion.open,
    linkSuggestion.rect?.left,
    linkSuggestion.rect?.top,
    linkSuggestion.rect?.bottom,
    linkSuggestion.items.length,
    linkSuggestion.loading,
    linkSuggestion.query,
  ],
  () => {
    if (!linkSuggestion.open) {
      pos.ready = false
      return
    }
    nextTick(place)
  },
)

function onWin(): void {
  if (linkSuggestion.open) place()
}
onMounted(() => {
  window.addEventListener('resize', onWin)
  window.addEventListener('scroll', onWin, true)
})
onBeforeUnmount(() => {
  window.removeEventListener('resize', onWin)
  window.removeEventListener('scroll', onWin, true)
})

const style = computed<CSSProperties>(() => ({
  left: `${pos.left}px`,
  top: pos.top != null ? `${pos.top}px` : 'auto',
  bottom: pos.bottom != null ? `${pos.bottom}px` : 'auto',
  maxHeight: `${pos.maxH}px`,
  width: 'min(18rem, calc(100vw - 1rem))',
  visibility: pos.ready ? 'visible' : 'hidden',
}))
</script>

<template>
  <div
    v-if="linkSuggestion.open && linkSuggestion.rect"
    ref="box"
    class="fixed z-[70] overflow-y-auto rounded-box border border-base-300 bg-base-100 p-1 shadow-lg"
    :style="style"
  >
    <div
      v-if="linkSuggestion.loading"
      class="flex items-center gap-2 px-2 py-2 text-sm opacity-70"
    >
      <span class="loading loading-spinner loading-xs" />
      <span>搜索中…</span>
    </div>
    <div
      v-else-if="!linkSuggestion.query.trim()"
      class="px-2 py-2 text-sm opacity-60"
    >
      输入关键词搜索日记…
    </div>
    <div
      v-else-if="!linkSuggestion.items.length"
      class="px-2 py-2 text-sm opacity-60"
    >
      无匹配的日记
    </div>
    <button
      v-for="(it, i) in linkSuggestion.items"
      v-else
      :key="it.id"
      type="button"
      class="block w-full truncate rounded-field px-2 py-1.5 text-left text-sm"
      :class="i === linkSuggestion.index ? 'bg-primary text-primary-content' : 'hover:bg-base-200'"
      @mousedown.prevent="selectCandidate(it)"
    >
      {{ it.label }}
    </button>
  </div>
</template>
