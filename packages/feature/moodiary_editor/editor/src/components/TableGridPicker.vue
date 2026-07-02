<script setup lang="ts">
// 表格尺寸网格选择器（最大 8×8）：悬停高亮左上 rows×cols 区域、显示「列 × 行」，点击/点按发 select。
// 移动端无 hover，点哪个格就插入那个尺寸（无预览，直接插）。插入后仍可用表内 +行/+列 继续扩。
import { ref } from 'vue'

const MAX_R = 8
const MAX_C = 8

const emit = defineEmits<{ (e: 'select', rows: number, cols: number): void }>()

const hr = ref(1)
const hc = ref(1)
</script>

<template>
  <div class="rounded-box border border-base-300 bg-base-100 p-2 shadow-lg">
    <div class="grid w-max gap-0.5" :style="{ gridTemplateColumns: `repeat(${MAX_C}, 1.25rem)` }">
      <template v-for="r in MAX_R" :key="r">
        <button
          v-for="c in MAX_C"
          :key="`${r}-${c}`"
          type="button"
          class="size-5 rounded-[3px] border"
          :class="r <= hr && c <= hc ? 'border-primary bg-primary/40' : 'border-base-300'"
          @mouseover="((hr = r), (hc = c))"
          @mousedown.prevent
          @click="emit('select', r, c)"
        />
      </template>
    </div>
    <div class="mt-1.5 text-center text-xs tabular-nums opacity-70">{{ hc }} × {{ hr }}</div>
  </div>
</template>
