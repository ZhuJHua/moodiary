<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref, shallowRef } from 'vue'
import { dismissKeyboard } from '../../editor/keyboard'
import { closeOverlay, openOverlay, type Overlay } from '../../editor/overlay'

const props = defineProps<{
  label?: string
  keepFocus?: boolean
  panelClass?: string
}>()

const emit = defineEmits<{
  (e: 'closed'): void
}>()

const GAP = 6
const PAD = 8

const anchor = shallowRef<HTMLElement | null>(null)
const panel = ref<HTMLElement>()
const isOpen = ref(false)
const style = ref<Record<string, string>>({})

const overlay: Overlay = { dismiss: () => close() }

function place(): void {
  const el = anchor.value
  const box = panel.value
  if (!el || !box || !isOpen.value) return
  const rect = el.getBoundingClientRect()
  const vv = window.visualViewport
  const top0 = vv?.offsetTop ?? 0
  const bottom0 = top0 + (vv?.height ?? window.innerHeight)
  const width = Math.min(box.offsetWidth, window.innerWidth - PAD * 2)
  const height = box.scrollHeight
  let top: number
  let origin = 'top center'
  if (height <= bottom0 - rect.bottom - GAP - PAD) {
    top = rect.bottom + GAP
  } else if (height <= rect.top - top0 - GAP - PAD) {
    top = rect.top - GAP - height
    origin = 'bottom center'
  } else {
    top = Math.max(top0 + PAD, bottom0 - PAD - height)
    origin = 'center'
  }
  let left = rect.left
  if (left + width > window.innerWidth - PAD) left = window.innerWidth - width - PAD
  if (left < PAD) left = PAD
  style.value = {
    left: `${Math.round(left)}px`,
    top: `${Math.round(top)}px`,
    maxHeight: `${Math.round(bottom0 - PAD - top)}px`,
    transformOrigin: origin,
  }
}

function follow(on: boolean): void {
  const vv = window.visualViewport
  const method = on ? 'addEventListener' : 'removeEventListener'
  window[method]('resize', place)
  vv?.[method]('resize', place)
}

function open(el: HTMLElement): void {
  if (!props.keepFocus) dismissKeyboard()
  anchor.value = el
  if (!isOpen.value) {
    isOpen.value = true
    openOverlay(overlay)
    follow(true)
  }
  void nextTick(place)
}

function close(): void {
  if (!isOpen.value) return
  isOpen.value = false
  follow(false)
  closeOverlay(overlay)
  emit('closed')
}

function onPanelDown(e: MouseEvent): void {
  if (props.keepFocus) e.preventDefault()
}

onBeforeUnmount(() => {
  follow(false)
  closeOverlay(overlay)
})

defineExpose({ open, close, isOpen, panel })
</script>

<template>
  <Teleport to="body">
    <template v-if="isOpen">
      <div
        class="fixed inset-0 z-[70]"
        @mousedown.prevent="close()"
        @touchstart.prevent="close()"
      ></div>
      <div
        ref="panel"
        class="moodiary-popover"
        :class="panelClass"
        :style="style"
        role="dialog"
        :aria-label="label"
        @mousedown="onPanelDown"
      >
        <slot />
      </div>
    </template>
  </Teleport>
</template>
