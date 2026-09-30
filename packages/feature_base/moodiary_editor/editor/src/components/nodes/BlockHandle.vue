<script setup lang="ts">
import IconEllipsis from '~icons/lucide/ellipsis'
import { useI18n } from 'vue-i18n'

defineProps<{
  variant: 'corner' | 'inline'
}>()

const emit = defineEmits<{
  (e: 'open', anchor: HTMLElement): void
}>()

const { t } = useI18n()
</script>

<template>
  <button
    type="button"
    class="moodiary-block__handle"
    :class="`moodiary-block__handle--${variant}`"
    :title="t('block.more')"
    @mousedown.prevent
    @click.stop="emit('open', $event.currentTarget as HTMLElement)"
  >
    <span class="moodiary-block__chip"><IconEllipsis class="size-[18px]" /></span>
  </button>
</template>
