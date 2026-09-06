<script setup lang="ts">
import { ref, watch, nextTick, computed, type Component } from 'vue'
import IconCheck from '~icons/lucide/check'

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
const menuRef = ref<HTMLElement>()
const menuStyle = ref<Record<string, string>>({})

const hasIcon = computed(() => props.items.some((item) => item.icon != null))
const hasActive = computed(() => props.items.some((item) => item.active))

function toggle(): void {
  emit('update:modelValue', !props.modelValue)
}

function close(): void {
  emit('update:modelValue', false)
}

function onSelect(key: string): void {
  emit('select', key)
  close()
}

function position(): void {
  const trigger = triggerRef.value
  if (!trigger) return
  const rect = trigger.getBoundingClientRect()
  const menu = menuRef.value
  const menuW = menu ? menu.offsetWidth : 200
  const menuH = menu ? menu.offsetHeight : Math.min(props.items.length * 44 + 12, 300)
  const gap = 6
  const pad = 8
  const vw = window.innerWidth
  const vh = window.innerHeight

  let top = rect.top - gap - menuH
  if (top < pad) {
    top = rect.bottom + gap
  }
  if (top + menuH > vh - pad) {
    top = vh - menuH - pad
  }

  let left = rect.left
  if (left + menuW > vw - pad) {
    left = vw - menuW - pad
  }
  if (left < pad) left = pad

  menuStyle.value = {
    left: `${Math.round(left)}px`,
    top: `${Math.round(top)}px`,
  }
}

watch(
  () => props.modelValue,
  async (open) => {
    if (open) {
      await nextTick()
      position()
    }
  },
)
</script>

<template>
  <div class="popup-menu-host">
    <div ref="triggerRef" @click="toggle">
      <slot name="trigger" />
    </div>
    <Teleport to="body">
      <template v-if="modelValue">
        <div class="fixed inset-0 z-[70]" @mousedown.prevent="close" @touchstart.prevent="close" />
        <div
          ref="menuRef"
          class="popup-menu-panel fixed z-[71] flex flex-col gap-0.5 p-1.5"
          :style="{ ...menuStyle, borderRadius: '16px' }"
        >
          <slot name="panel">
            <button
              v-for="item in items"
              :key="item.key"
              type="button"
              class="popup-menu-item flex items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm font-medium transition-colors"
              :class="{
                'popup-menu-item--active': item.active,
                'popup-menu-item--destructive': item.destructive,
              }"
              @mousedown.prevent
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
          </slot>
        </div>
      </template>
    </Teleport>
  </div>
</template>

<style scoped>
.popup-menu-panel {
  background: var(--app-hover);
  min-width: 168px;
  max-width: 320px;
  box-shadow:
    0 4px 16px rgba(0, 0, 0, 0.2),
    0 2px 4px rgba(0, 0, 0, 0.14);
}

.popup-menu-item {
  color: var(--app-on-surface);
  background: transparent;
  border: none;
  cursor: pointer;
  outline: none;
  -webkit-tap-highlight-color: transparent;
}
.popup-menu-item:hover {
  background: var(--app-selected);
}

.popup-menu-item--active {
  color: var(--app-on-secondary);
  background: var(--app-secondary);
  font-weight: 600;
}
.popup-menu-item--active:hover {
  background: var(--app-secondary);
}

.popup-menu-item--destructive {
  color: var(--app-error);
}

.popup-menu-panel {
  animation: popup-in 0.2s cubic-bezier(0.33, 1, 0.68, 1);
}
@keyframes popup-in {
  from {
    opacity: 0;
    transform: scale(0.9);
    transform-origin: bottom center;
  }
  to {
    opacity: 1;
    transform: scale(1);
    transform-origin: bottom center;
  }
}
</style>
