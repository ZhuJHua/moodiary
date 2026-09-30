<script setup lang="ts">
import { runUndoToast, undoToast } from '../../editor/undo-toast'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
</script>

<template>
  <div class="relative">
    <div
      v-if="undoToast.visible"
      class="absolute bottom-full left-1/2 z-[80] mb-3 -translate-x-1/2 whitespace-nowrap"
      role="status"
    >
      <div class="alert alert-soft py-2 pr-2 shadow-lg">
        <span>{{ undoToast.message }}</span>
        <button type="button" class="btn btn-sm btn-ghost text-primary" @mousedown.prevent @click="runUndoToast">
          {{ t('block.undo') }}
        </button>
      </div>
    </div>
  </div>
</template>
