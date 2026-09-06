<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { NodeViewContent, NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import IconCopy from '~icons/lucide/copy'
import IconCheck from '~icons/lucide/check'

const props = defineProps(nodeViewProps)

const language = computed(() => {
  const l = props.node.attrs.language as string | null
  return l && l.length ? l : '纯文本'
})

const copied = ref(false)
let copiedTimer = 0
async function copy(): Promise<void> {
  const text = props.node.textContent
  try {
    await navigator.clipboard.writeText(text)
  } catch {
    const ta = document.createElement('textarea')
    ta.value = text
    ta.style.position = 'fixed'
    ta.style.opacity = '0'
    document.body.appendChild(ta)
    ta.select()
    try {
      document.execCommand('copy')
    } catch {
    }
    document.body.removeChild(ta)
  }
  copied.value = true
  clearTimeout(copiedTimer)
  copiedTimer = window.setTimeout(() => (copied.value = false), 1500)
}
onBeforeUnmount(() => clearTimeout(copiedTimer))
</script>

<template>
  <NodeViewWrapper class="moodiary-code-block">
    <div class="moodiary-code-block__head" contenteditable="false">
      <span class="moodiary-code-block__lang">{{ language }}</span>
      <button
        class="moodiary-code-block__copy"
        type="button"
        :title="copied ? '已复制' : '复制'"
        @click="copy"
      >
        <component :is="copied ? IconCheck : IconCopy" class="size-4" />
        <span>{{ copied ? '已复制' : '复制' }}</span>
      </button>
    </div>
    <!-- NodeViewContent 默认内联 white-space: pre-wrap，这里覆盖为 pre -->
    <pre><NodeViewContent as="code" style="white-space: pre" /></pre>
  </NodeViewWrapper>
</template>
