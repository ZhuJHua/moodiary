<script setup lang="ts">
import { computed, onBeforeUnmount, ref, shallowRef } from 'vue'
import type { Editor } from '@tiptap/core'
import type { Node as PMNode } from '@tiptap/pm/model'
import { closeHistory } from '@tiptap/pm/history'
import IconArrowUp from '~icons/lucide/arrow-up-to-line'
import IconArrowDown from '~icons/lucide/arrow-down-to-line'
import IconTrash from '~icons/lucide/trash-2'
import Popover from '../ui/Popover.vue'
import WidthControl from './WidthControl.vue'
import { insertParagraph } from '../../editor/block-caret'
import { blockMenu, registerBlockMenu, type BlockTarget } from '../../editor/block-menu'
import { hideUndoToast, showUndoToast } from '../../editor/undo-toast'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  editor: Editor
}>()

const { t } = useI18n()

const pop = ref<InstanceType<typeof Popover>>()
const target = shallowRef<BlockTarget | null>(null)
const node = shallowRef<PMNode | null>(null)

const sizable = computed(() => target.value?.kind !== 'audio')
const widthPercent = computed(() => {
  const v = node.value?.attrs.widthPercent
  return typeof v === 'number' ? v : null
})

function position(): number | null {
  const pos = target.value?.getPos()
  return pos == null ? null : pos
}

function refresh(): void {
  const pos = position()
  node.value = pos == null ? null : props.editor.state.doc.nodeAt(pos)
}

function open(next: BlockTarget): void {
  target.value = next
  blockMenu.owner = next.owner
  blockMenu.previewWidth = null
  refresh()
  props.editor.on('transaction', refresh)
  pop.value?.open(next.anchor)
}

function onClosed(): void {
  props.editor.off('transaction', refresh)
  target.value = null
  blockMenu.owner = null
  blockMenu.previewWidth = null
}

function commitWidth(value: number | null): void {
  blockMenu.previewWidth = null
  const pos = position()
  const current = node.value
  if (pos == null || !current) return
  props.editor.view.dispatch(
    props.editor.state.tr.setNodeMarkup(pos, undefined, { ...current.attrs, widthPercent: value }),
  )
}

function insert(after: boolean): void {
  const pos = position()
  const current = node.value
  pop.value?.close()
  if (pos == null || !current) return
  const { view } = props.editor
  view.focus()
  const tr = view.state.tr
  insertParagraph(tr, after ? pos + current.nodeSize : pos)
  view.dispatch(tr.scrollIntoView())
}

function remove(): void {
  const pos = position()
  const current = node.value
  pop.value?.close()
  if (pos == null || !current) return
  props.editor.view.dispatch(closeHistory(props.editor.state.tr).delete(pos, pos + current.nodeSize))
  showUndoToast(t('block.deleted'), () => props.editor.commands.undo())
  props.editor.once('update', hideUndoToast)
}

registerBlockMenu(open)
onBeforeUnmount(() => {
  registerBlockMenu(null)
  onClosed()
})
</script>

<template>
  <Popover ref="pop" keep-focus panel-class="w-56" :label="t('block.more')" @closed="onClosed">
    <template v-if="sizable && node">
      <WidthControl
        :model-value="widthPercent"
        @preview="blockMenu.previewWidth = $event"
        @commit="commitWidth"
      />
      <div class="moodiary-pop-divider"></div>
    </template>
    <button type="button" class="moodiary-pop-item" @click="insert(false)">
      <IconArrowUp />{{ t('block.insertAbove') }}
    </button>
    <button type="button" class="moodiary-pop-item" @click="insert(true)">
      <IconArrowDown />{{ t('block.insertBelow') }}
    </button>
    <button type="button" class="moodiary-pop-item is-danger" @click="remove">
      <IconTrash />{{ t('block.delete') }}
    </button>
  </Popover>
</template>
