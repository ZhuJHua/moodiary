<script setup lang="ts">
// 文末双链面板（原 Flutter 侧渲染，搬进 webview 落到文档流末尾——滚到底自然出现）。
// 条目点击复用 linkTap 通道（Flutter 页内跳转），图谱入口经 openGraph 回跳。
import { computed } from 'vue'
import { post } from '../bridge/post'
import type { EditorLinkItem, EditorLinks } from '../bridge/meta'
import IconLink from '~icons/lucide/link'
import IconWaypoints from '~icons/lucide/waypoints'
import IconArrowUpRight from '~icons/lucide/arrow-up-right'
import IconCornerDownLeft from '~icons/lucide/corner-down-left'
import IconChevronRight from '~icons/lucide/chevron-right'

const props = defineProps<{ links: EditorLinks }>()

const sections = computed(() => [
  { label: props.links.outgoingLabel, items: props.links.outgoing, outgoing: true },
  { label: props.links.incomingLabel, items: props.links.incoming, outgoing: false },
])

function onOpen(item: EditorLinkItem): void {
  post('linkTap', { id: item.id })
}
</script>

<template>
  <div class="links-panel">
    <div class="links-head">
      <IconLink class="links-head-icon" />
      <span class="links-head-title">{{ links.title }}</span>
      <span class="links-count">{{ links.outgoing.length + links.incoming.length }}</span>
      <span class="links-spacer" />
      <button
        type="button"
        class="links-graph-btn"
        :title="links.graphTip"
        @mousedown.prevent
        @click="post('openGraph')"
      >
        <IconWaypoints class="size-5" />
      </button>
    </div>
    <template v-for="section in sections" :key="section.label">
      <div v-if="section.items.length" class="links-section-label">{{ section.label }}</div>
      <button
        v-for="item in section.items"
        :key="item.id"
        type="button"
        class="links-item"
        @mousedown.prevent
        @click="onOpen(item)"
      >
        <span class="links-item-leading" :class="{ 'links-item-leading--out': section.outgoing }">
          <IconArrowUpRight v-if="section.outgoing" class="size-[18px]" />
          <IconCornerDownLeft v-else class="size-[18px]" />
        </span>
        <span class="links-item-body">
          <span class="links-item-title">{{ item.title }}</span>
          <span v-if="item.subtitle" class="links-item-subtitle">{{ item.subtitle }}</span>
        </span>
        <IconChevronRight class="links-item-chevron" />
      </button>
    </template>
  </div>
</template>

<style scoped>
.links-panel {
  flex: 0 0 auto;
  margin: 24px 16px 24px;
  padding: 12px 8px 8px 14px;
  border-radius: 16px;
  background: var(--app-surface-low);
  font-family: var(--app-font-sans);
  display: flex;
  flex-direction: column;
}

.links-head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding-right: 4px;
}
.links-head-icon {
  width: 18px;
  height: 18px;
  color: var(--app-primary);
  flex: none;
}
.links-head-title {
  color: var(--app-on-surface);
  font-size: calc(14px * var(--app-font-scale, 1));
  font-weight: 600;
}
.links-count {
  padding: 1px 7px;
  border-radius: 999px;
  background: var(--app-selected);
  color: var(--app-on-surface-variant);
  font-size: calc(11px * var(--app-font-scale, 1));
}
.links-spacer {
  flex: 1;
}
.links-graph-btn {
  margin: 0;
  padding: 8px;
  border: none;
  border-radius: 999px;
  background: transparent;
  color: var(--app-on-surface);
  cursor: pointer;
  outline: none;
  -webkit-tap-highlight-color: transparent;
}
.links-graph-btn:hover {
  background: var(--app-hover);
}

.links-section-label {
  padding: 8px 0 2px 6px;
  color: var(--app-on-surface-variant);
  font-size: calc(11px * var(--app-font-scale, 1));
}

.links-item {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 0;
  padding: 8px 6px;
  border: none;
  border-radius: 12px;
  background: transparent;
  font-family: inherit;
  text-align: left;
  cursor: pointer;
  outline: none;
  -webkit-tap-highlight-color: transparent;
  min-width: 0;
}
.links-item:hover {
  background: var(--app-hover);
}
.links-item-leading {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 10px;
  background: var(--app-selected);
  color: var(--app-on-surface-variant);
  flex: none;
}
.links-item-leading--out {
  color: var(--app-primary);
}
.links-item-body {
  display: flex;
  flex-direction: column;
  min-width: 0;
  flex: 1;
}
.links-item-title {
  color: var(--app-on-surface);
  font-size: calc(14px * var(--app-font-scale, 1));
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.links-item-subtitle {
  color: var(--app-on-surface-variant);
  font-size: calc(12px * var(--app-font-scale, 1));
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.links-item-chevron {
  width: 18px;
  height: 18px;
  color: var(--app-on-surface-variant);
  flex: none;
}
</style>
