<script setup lang="ts">
import { computed, ref } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import MediaSizeMenu from './MediaSizeMenu.vue'
import { editable } from '../../editor/editable'
import { displaySrc } from '../../editor/media'
import { useI18n } from 'vue-i18n'

const props = defineProps(nodeViewProps)

const { t } = useI18n()

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
const shown = computed(() => draft.value ?? widthPercent.value)

const wrapperStyle = computed(() =>
  shown.value === null ? undefined : { maxWidth: `${shown.value}%` },
)

function commit(value: number | null): void {
  props.updateAttributes({ widthPercent: value })
}
</script>

<template>
  <NodeViewWrapper
    class="moodiary-image"
    :class="{ 'is-selected': selected }"
    :style="wrapperStyle"
    contenteditable="false"
  >
    <img class="moodiary-image__img" :src="src" :alt="alt" :title="title" draggable="false" />
    <MediaSizeMenu
      v-if="editable"
      :model-value="widthPercent"
      :title="t('image.size')"
      @update:model-value="commit"
      @preview="draft = $event"
    />
  </NodeViewWrapper>
</template>
