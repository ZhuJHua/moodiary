<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'
import {
  closeSearch,
  editorSearch,
  nextMatch,
  prevMatch,
  replaceAllMatches,
  replaceOne,
  setReplace,
  setTerm,
  toggleCase,
} from '../editor/search'
import IconUp from '~icons/lucide/chevron-up'
import IconDown from '~icons/lucide/chevron-down'
import IconClose from '~icons/lucide/x'
import { useI18n } from 'vue-i18n'

defineProps<{ platform: 'mobile' | 'desktop' }>()

const { t } = useI18n()

const findInput = ref<HTMLInputElement | null>(null)

watch(
  () => editorSearch.open,
  (open) => {
    if (open)
      nextTick(() => {
        findInput.value?.focus()
        findInput.value?.select()
      })
  },
)

function onFindKey(e: KeyboardEvent): void {
  if (e.key === 'Enter') {
    e.preventDefault()
    e.shiftKey ? prevMatch() : nextMatch()
  } else if (e.key === 'Escape') {
    e.preventDefault()
    closeSearch()
  }
}
</script>

<template>
  <div
    v-if="editorSearch.open"
    class="moodiary-search flex-none bg-base-100 px-2 py-1.5"
    :class="platform === 'desktop' ? 'border-b border-base-300' : 'border-t border-base-300'"
  >
    <div class="grid grid-cols-[1fr_auto] items-center gap-x-1.5 gap-y-1">
      <input
        ref="findInput"
        :value="editorSearch.term"
        type="text"
        :placeholder="t('search.findPlaceholder')"
        class="input input-xs w-full rounded-md"
        @input="setTerm(($event.target as HTMLInputElement).value)"
        @keydown="onFindKey"
      />
      <div class="flex items-center gap-0.5">
        <span class="min-w-[2.5rem] px-0.5 text-right text-xs tabular-nums opacity-60">
          {{ editorSearch.term ? `${editorSearch.current}/${editorSearch.count}` : '' }}
        </span>
        <button
          class="btn btn-ghost btn-xs btn-square rounded-md"
          :class="{ 'btn-active text-primary': editorSearch.caseSensitive }"
          type="button"
          :title="t('search.matchCase')"
          @mousedown.prevent
          @click="toggleCase"
        >
          <span class="text-[11px] font-bold">Aa</span>
        </button>
        <button class="btn btn-ghost btn-xs btn-square rounded-md" type="button" :title="t('search.previous')" @mousedown.prevent @click="prevMatch">
          <IconUp class="size-4" />
        </button>
        <button class="btn btn-ghost btn-xs btn-square rounded-md" type="button" :title="t('search.next')" @mousedown.prevent @click="nextMatch">
          <IconDown class="size-4" />
        </button>
        <button class="btn btn-ghost btn-xs btn-square rounded-md" type="button" :title="t('search.close')" @mousedown.prevent @click="closeSearch">
          <IconClose class="size-4" />
        </button>
      </div>

      <input
        :value="editorSearch.replace"
        type="text"
        :placeholder="t('search.replacePlaceholder')"
        class="input input-xs w-full rounded-md"
        @input="setReplace(($event.target as HTMLInputElement).value)"
      />
      <div class="flex items-center justify-end gap-0.5">
        <button class="btn btn-ghost btn-xs rounded-md" type="button" @mousedown.prevent @click="replaceOne">{{ t('search.replace') }}</button>
        <button class="btn btn-ghost btn-xs rounded-md" type="button" @mousedown.prevent @click="replaceAllMatches">{{ t('search.replaceAll') }}</button>
      </div>
    </div>
  </div>
</template>
