<script setup lang="ts">
// 图片节点视图：正文里仍然是一个真 <img> —— App.vue 的全屏画廊靠 closest('img') 命中，
// 换成 background-image 就点不开了。外层包一层承载宽度与右下角的尺寸角标。
//
// 角标只在可编辑态渲染（阅读态只剩图，尺寸照常生效）。它是 <img> 的兄弟节点而非子节点
// （img 是空元素），故点角标时 closest('img') 为 null，天然不会触发全屏画廊 —— 「点图看大图」
// 这条既有链路一行都不用改。
//
// 调节用 daisyUI range：无极（step=1）但档位磁吸（见 snapWidthPercent），刻度行可直接点。
// 拖动期间只改本地 draft 驱动预览，松手（change）才落一次 updateAttributes —— 否则一次拖拽会
// 往 undo 栈里塞几十步。
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
/** 拖动中的预览值；null = 不在拖动，显示已落库的值。 */
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
/** 实际呈现的宽度：拖动中看 draft，否则看落库值。 */
const shown = computed(() => draft.value ?? widthPercent.value)

// 宽度必须落在外层（其包含块是正文列，百分比才有确定参照）；<img> 再撑满外层。
// 用 max-width 而非 width：外层保持 fit-content，于是实际宽度 = min(图片原始宽, N%×列宽)，
// 档位语义是「上限」。写 width 会把 60px 的表情图硬拉到列宽的 N%，糊得很明显。
const wrapperStyle = computed(() =>
  shown.value === null ? undefined : { maxWidth: `${shown.value}%` },
)
// 默认档没有具体百分比，滑块停在满栏。
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

// 兜底：个别 WebView 的 range 不发 change，关面板时把未提交的预览落下去。
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

          <!-- 刻度 + 可点档位。min 取 25 使四档正好四等分，justify-between 即与滑轨对齐。 -->
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
