<script setup lang="ts">
import { computed } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import BlockHandle from './BlockHandle.vue'
import { blockMenu, openBlockMenu } from '../../editor/block-menu'
import { editable } from '../../editor/editable'
import { displaySrc } from '../../editor/media'

const props = defineProps(nodeViewProps)

const owner = Symbol('image')
const menuOpen = computed(() => blockMenu.owner === owner)

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
const shown = computed(() =>
  menuOpen.value && blockMenu.previewWidth !== null ? blockMenu.previewWidth : widthPercent.value,
)

const wrapperStyle = computed(() =>
  shown.value === null ? undefined : { maxWidth: `${shown.value}%` },
)

function openMenu(anchor: HTMLElement): void {
  openBlockMenu({ owner, kind: 'image', anchor, getPos: () => props.getPos() })
}
</script>

<template>
  <NodeViewWrapper
    class="moodiary-image"
    :class="{ 'is-selected': selected, 'is-menu-open': menuOpen }"
    :style="wrapperStyle"
    contenteditable="false"
  >
    <img
      class="moodiary-image__img moodiary-block__body"
      :src="src"
      :alt="alt"
      :title="title"
      draggable="false"
    />
    <BlockHandle v-if="editable" variant="corner" @open="openMenu" />
  </NodeViewWrapper>
</template>
