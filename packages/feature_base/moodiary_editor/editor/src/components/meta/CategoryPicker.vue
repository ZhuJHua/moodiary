<script setup lang="ts">
import { ref } from 'vue'
import IconCheck from '~icons/lucide/check'
import Popover from '../ui/Popover.vue'
import { post } from '../../bridge/post'
import type { EditorMeta } from '../../bridge/meta'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  meta: EditorMeta
}>()

const { t } = useI18n()

const pop = ref<InstanceType<typeof Popover>>()

function select(id: string | null): void {
  pop.value?.close()
  if (id !== (props.meta.categoryId ?? null)) post('changeCategory', { id })
}

defineExpose({ open: (anchor: HTMLElement) => pop.value?.open(anchor) })
</script>

<template>
  <Popover ref="pop" panel-class="w-[236px]" :label="t('meta.category')">
    <button
      type="button"
      class="moodiary-pop-item"
      :class="{ 'is-active': !meta.categoryId }"
      @click="select(null)"
    >
      <span class="flex-1">{{ t('meta.noCategory') }}</span>
      <IconCheck v-if="!meta.categoryId" />
    </button>
    <div class="flex max-h-[240px] flex-col gap-0.5 overflow-y-auto overscroll-contain">
      <button
        v-for="c in meta.categories ?? []"
        :key="c.id"
        type="button"
        class="moodiary-pop-item"
        :class="{ 'is-active': c.id === meta.categoryId }"
        @click="select(c.id)"
      >
        <span class="min-w-0 flex-1 truncate">{{ c.name }}</span>
        <IconCheck v-if="c.id === meta.categoryId" />
      </button>
    </div>
  </Popover>
</template>
