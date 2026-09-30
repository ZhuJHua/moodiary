<script setup lang="ts">
import { ref } from 'vue'

const ITEM = 40

const props = defineProps<{
  items: string[]
  label: string
}>()

const list = ref<HTMLElement>()

function scrollTo(index: number): void {
  if (list.value) list.value.scrollTop = index * ITEM
}

function current(): number {
  const top = list.value?.scrollTop ?? 0
  return Math.min(props.items.length - 1, Math.max(0, Math.round(top / ITEM)))
}

defineExpose({ scrollTo, current })
</script>

<template>
  <div class="moodiary-wheel">
    <div class="moodiary-wheel__band" aria-hidden="true"></div>
    <div ref="list" class="moodiary-wheel__list" role="listbox" :aria-label="label" tabindex="-1">
      <div v-for="(item, i) in items" :key="i" class="moodiary-wheel__item" @click="list?.scrollTo({ top: i * ITEM, behavior: 'smooth' })">
        {{ item }}
      </div>
    </div>
  </div>
</template>
