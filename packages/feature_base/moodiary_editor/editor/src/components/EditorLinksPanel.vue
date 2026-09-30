<script setup lang="ts">
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
  <div class="links-panel card mx-4 my-6 bg-base-200">
    <div class="card-body gap-1 p-3 pl-3.5">
      <div class="flex items-center gap-2">
        <IconLink class="size-4 opacity-60" />
        <span class="text-sm font-semibold">{{ links.title }}</span>
        <span class="badge badge-sm badge-ghost">{{ links.outgoing.length + links.incoming.length }}</span>
        <span class="flex-1" />
        <button
          type="button"
          class="btn btn-ghost btn-sm btn-square"
          :title="links.graphTip"
          @mousedown.prevent
          @click="post('openGraph')"
        >
          <IconWaypoints class="size-5" />
        </button>
      </div>
      <template v-for="section in sections" :key="section.label">
        <template v-if="section.items.length">
          <div class="mt-2 px-1 text-xs opacity-60">{{ section.label }}</div>
          <ul class="list">
            <li v-for="item in section.items" :key="item.id">
              <button
                type="button"
                class="list-row w-full items-center rounded-field px-1 py-2 text-left active:bg-base-300"
                @mousedown.prevent
                @click="onOpen(item)"
              >
                <span
                  class="grid size-8 place-items-center rounded-full"
                  :class="section.outgoing ? 'bg-primary/15 text-primary' : 'bg-base-300'"
                >
                  <IconArrowUpRight v-if="section.outgoing" class="size-[18px]" />
                  <IconCornerDownLeft v-else class="size-[18px]" />
                </span>
                <span class="list-col-grow min-w-0">
                  <span class="block truncate text-sm font-medium">{{ item.title }}</span>
                  <span v-if="item.subtitle" class="block truncate text-xs opacity-60">{{ item.subtitle }}</span>
                </span>
                <IconChevronRight class="size-4 opacity-40" />
              </button>
            </li>
          </ul>
        </template>
      </template>
    </div>
  </div>
</template>

<style scoped>
.links-panel {
  flex: 0 0 auto;
  font-family: var(--app-font-sans);
}
</style>
