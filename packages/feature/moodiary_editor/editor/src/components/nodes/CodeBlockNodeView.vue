<script setup lang="ts">
// 代码块节点视图：左上角显示**只读**语言标签，右上角复制按钮，下方可编辑代码（NodeViewContent，as=code）。
// 语法高亮由 CodeBlockLowlight 的 PM 插件按 node.attrs.language 着色（语言经 ```lang 输入规则或旧
// markdown 设定；本视图不提供改语言入口，仅展示）。输出 .hljs-* span，配色见 moodiary-editor.css。
import { computed, onBeforeUnmount, ref } from 'vue'
import { NodeViewContent, NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import IconCopy from '~icons/material-symbols/content-copy-rounded'
import IconCheck from '~icons/material-symbols/check-rounded'

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
    // webview 里 async clipboard 可能不可用，退回 execCommand。
    const ta = document.createElement('textarea')
    ta.value = text
    ta.style.position = 'fixed'
    ta.style.opacity = '0'
    document.body.appendChild(ta)
    ta.select()
    try {
      document.execCommand('copy')
    } catch {
      /* no-op */
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
    <pre><NodeViewContent as="code" /></pre>
  </NodeViewWrapper>
</template>
