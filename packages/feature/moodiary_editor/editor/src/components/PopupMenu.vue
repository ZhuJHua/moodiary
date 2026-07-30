<script setup lang="ts">
import { ref, watch, nextTick, computed, type Component } from 'vue'
import IconCheck from '~icons/material-symbols/check-rounded'

export interface PopupMenuItem {
  key: string
  label: string
  icon?: Component
  active: boolean
  /** 破坏性操作（删除等）以 error 色呈现。 */
  destructive?: boolean
}

// items 与 #panel 二选一：给 items 就是标准条目菜单，给 #panel 则面板内容自定义
//（图片尺寸滑块用后者），定位 / 遮罩 / 动画 / 面板外观共用这一份。
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
  // 估算：取菜单实际尺寸；若尚未挂载则用条目数估算。
  const menuW = menu ? menu.offsetWidth : 200
  const menuH = menu ? menu.offsetHeight : Math.min(props.items.length * 44 + 12, 300)
  const gap = 6
  const pad = 8
  const vw = window.innerWidth
  const vh = window.innerHeight

  // 默认向上弹出（工具栏在底部）
  let top = rect.top - gap - menuH
  // 上方空间不足则向下
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
        <!-- 背景遮罩：点击关闭；@mousedown.prevent 阻止 contenteditable 失焦 -->
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
              <!-- 前导图标位（任一条目有图标即留空位保证对齐） -->
              <span v-if="hasIcon" class="flex w-5 shrink-0 justify-center">
                <component :is="item.icon" v-if="item.icon" class="size-[19px]" />
              </span>
              <span class="flex-1 whitespace-nowrap">{{ item.label }}</span>
              <!-- 选中标记 -->
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
/* —— 面板：与 Flutter MoodiaryMenuButton 一致 —— */
.popup-menu-panel {
  background: var(--app-hover); /* surfaceContainerHigh */
  min-width: 168px;
  max-width: 320px;
  box-shadow:
    0 4px 16px rgba(0, 0, 0, 0.2),
    0 2px 4px rgba(0, 0, 0, 0.14);
}

/* 条目默认色 */
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

/* 选中态：secondaryContainer + onSecondaryContainer + 加粗 */
.popup-menu-item--active {
  color: var(--app-on-secondary);
  background: var(--app-secondary);
  font-weight: 600;
}
.popup-menu-item--active:hover {
  background: var(--app-secondary);
}

/* 破坏性条目：error 色 */
.popup-menu-item--destructive {
  color: var(--app-error);
}

/* 入场 / 出场动画：缩放 + 淡入，与 Flutter 的 easeOutCubic / easeInCubic 对齐 */
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
