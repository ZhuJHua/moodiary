<script setup lang="ts">
// `[[` 双链候选弹层：消费 diary-link.ts 的响应式 linkSuggestion 状态。
// 定位做碰撞规避：宽度封顶不超屏；水平超出右边回拉、不小于左边距；下方空间够则在光标下方，
// 不够则翻到上方（按光标顶边 bottom 锚定，免测高度）；max-height 按所选侧可用空间收缩、内部滚动。
// 测量需先渲染，故用 ready 门控（首次定位完成前 visibility:hidden，避免在错误位置闪一帧）。
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

  // 水平：超出右边回拉，不小于左边距。
  let left = r.left
  if (left + w > vw - MARGIN) left = vw - w - MARGIN
  if (left < MARGIN) left = MARGIN

  const belowSpace = vh - r.bottom - GAP - MARGIN
  const aboveSpace = r.top - GAP - MARGIN

  // 下方放得下 或 下方空间≥上方 → 放下方（top 锚定）；否则翻上方（bottom 锚定，免测高度）。
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
  // 宽度封顶：不超过屏宽减边距，窄屏自动收窄。
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
    <!-- 加载中 -->
    <div
      v-if="linkSuggestion.loading"
      class="flex items-center gap-2 px-2 py-2 text-sm opacity-70"
    >
      <span class="loading loading-spinner loading-xs" />
      <span>搜索中…</span>
    </div>
    <!-- 空查询：提示输入 -->
    <div
      v-else-if="!linkSuggestion.query.trim()"
      class="px-2 py-2 text-sm opacity-60"
    >
      输入关键词搜索日记…
    </div>
    <!-- 无匹配 -->
    <div
      v-else-if="!linkSuggestion.items.length"
      class="px-2 py-2 text-sm opacity-60"
    >
      无匹配的日记
    </div>
    <!-- 结果 -->
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
