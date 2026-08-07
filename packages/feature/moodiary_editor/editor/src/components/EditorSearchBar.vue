<script setup lang="ts">
// 编辑器查找/替换条（daisyUI）。两行用 grid `1fr auto`：两个输入框都在 1fr 列 → 等宽对齐；按钮在
// auto 列右对齐。控件用 xs 尺寸（更矮、更窄，给输入框让出宽度）、圆角 rounded-md（比主题 radius-field 小）。
// 位置由 platform 决定边框（桌面工具栏下=border-b、移动工具栏上=border-t）。
// 按钮 @mousedown.prevent 保持查找框焦点；Enter=下一个、Shift+Enter=上一个、Esc=关闭。
import { nextTick, ref, watch } from 'vue'
import {
  closeSearch,
  editorSearch,
  nextMatch,
  prevMatch,
  replaceAllMatches,
  replaceOne,
  setReplace,
  setTerm,
  toggleCase,
} from '../editor/search'
import IconUp from '~icons/lucide/chevron-up'
import IconDown from '~icons/lucide/chevron-down'
import IconClose from '~icons/lucide/x'

defineProps<{ platform: 'mobile' | 'desktop' }>()

const findInput = ref<HTMLInputElement | null>(null)

watch(
  () => editorSearch.open,
  (open) => {
    if (open)
      nextTick(() => {
        findInput.value?.focus()
        findInput.value?.select()
      })
  },
)

function onFindKey(e: KeyboardEvent): void {
  if (e.key === 'Enter') {
    e.preventDefault()
    e.shiftKey ? prevMatch() : nextMatch()
  } else if (e.key === 'Escape') {
    e.preventDefault()
    closeSearch()
  }
}
</script>

<template>
  <div
    v-if="editorSearch.open"
    class="moodiary-search flex-none bg-base-100 px-2 py-1.5"
    :class="platform === 'desktop' ? 'border-b border-base-300' : 'border-t border-base-300'"
  >
    <div class="grid grid-cols-[1fr_auto] items-center gap-x-1.5 gap-y-1">
      <!-- 查找行 -->
      <input
        ref="findInput"
        :value="editorSearch.term"
        type="text"
        placeholder="查找"
        class="input input-xs w-full rounded-md"
        @input="setTerm(($event.target as HTMLInputElement).value)"
        @keydown="onFindKey"
      />
      <div class="flex items-center gap-0.5">
        <span class="min-w-[2.5rem] px-0.5 text-right text-xs tabular-nums opacity-60">
          {{ editorSearch.term ? `${editorSearch.current}/${editorSearch.count}` : '' }}
        </span>
        <button
          class="btn btn-ghost btn-xs btn-square rounded-md"
          :class="{ 'btn-active text-primary': editorSearch.caseSensitive }"
          type="button"
          title="区分大小写"
          @mousedown.prevent
          @click="toggleCase"
        >
          <span class="text-[11px] font-bold">Aa</span>
        </button>
        <button class="btn btn-ghost btn-xs btn-square rounded-md" type="button" title="上一个" @mousedown.prevent @click="prevMatch">
          <IconUp class="size-4" />
        </button>
        <button class="btn btn-ghost btn-xs btn-square rounded-md" type="button" title="下一个" @mousedown.prevent @click="nextMatch">
          <IconDown class="size-4" />
        </button>
        <button class="btn btn-ghost btn-xs btn-square rounded-md" type="button" title="关闭" @mousedown.prevent @click="closeSearch">
          <IconClose class="size-4" />
        </button>
      </div>

      <!-- 替换行 -->
      <input
        :value="editorSearch.replace"
        type="text"
        placeholder="替换为"
        class="input input-xs w-full rounded-md"
        @input="setReplace(($event.target as HTMLInputElement).value)"
      />
      <div class="flex items-center justify-end gap-0.5">
        <button class="btn btn-ghost btn-xs rounded-md" type="button" @mousedown.prevent @click="replaceOne">替换</button>
        <button class="btn btn-ghost btn-xs rounded-md" type="button" @mousedown.prevent @click="replaceAllMatches">全部</button>
      </div>
    </div>
  </div>
</template>
