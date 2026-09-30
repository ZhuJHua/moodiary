<script setup lang="ts">
import { computed, ref, watch, type Component } from 'vue'
import IconCheck from '~icons/lucide/check'
import Popover from './ui/Popover.vue'

export interface PopupMenuItem {
  key: string
  label: string
  icon?: Component
  active: boolean
  destructive?: boolean
}

const props = withDefaults(
  defineProps<{
    items?: PopupMenuItem[]
    modelValue: boolean
  }>(),
  { items: () => [] },
)

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'select', key: string): void
}>()

const triggerRef = ref<HTMLElement>()
const pop = ref<InstanceType<typeof Popover>>()

const hasIcon = computed(() => props.items.some((item) => item.icon != null))
const hasActive = computed(() => props.items.some((item) => item.active))

function onSelect(key: string): void {
  emit('select', key)
  emit('update:modelValue', false)
}

watch(
  () => props.modelValue,
  (open) => {
    if (open && triggerRef.value) pop.value?.open(triggerRef.value)
    else pop.value?.close()
  },
)
</script>

<template>
  <div class="popup-menu-host">
    <div ref="triggerRef" @click="emit('update:modelValue', !modelValue)">
      <slot name="trigger" />
    </div>
    <Popover ref="pop" keep-focus panel-class="min-w-42 max-w-80" @closed="emit('update:modelValue', false)">
      <button
        v-for="item in items"
        :key="item.key"
        type="button"
        class="moodiary-pop-item"
        :class="{ 'is-active': item.active, 'is-danger': item.destructive }"
        @click.stop="onSelect(item.key)"
      >
        <span v-if="hasIcon" class="flex w-5 shrink-0 justify-center">
          <component :is="item.icon" v-if="item.icon" class="size-[19px]" />
        </span>
        <span class="flex-1 whitespace-nowrap">{{ item.label }}</span>
        <span v-if="hasActive" class="flex w-[18px] shrink-0 justify-center">
          <IconCheck v-if="item.active" class="size-[18px]" />
        </span>
      </button>
    </Popover>
  </div>
</template>
