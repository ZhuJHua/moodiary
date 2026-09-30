<script setup lang="ts">
import { ref } from 'vue'
import IconLocateFixed from '~icons/lucide/locate-fixed'
import IconPlus from '~icons/lucide/plus'
import IconSettings from '~icons/lucide/settings'
import IconX from '~icons/lucide/x'
import Popover from '../ui/Popover.vue'
import { post } from '../../bridge/post'
import type { EditorMeta } from '../../bridge/meta'
import { placeIcon } from './icons'
import { useI18n } from 'vue-i18n'

defineProps<{
  meta: EditorMeta
}>()

const { t } = useI18n()

const pop = ref<InstanceType<typeof Popover>>()

function act(type: string, payload?: unknown): void {
  pop.value?.close()
  post(type, payload)
}

function open(anchor: HTMLElement): void {
  pop.value?.open(anchor)
  post('locateForPlaces')
}

defineExpose({ open })
</script>

<template>
  <Popover ref="pop" panel-class="w-[236px]" :label="t('meta.place')">
    <button v-if="meta.positionAutoLabel" type="button" class="moodiary-pop-item" @click="act('fetchPosition')">
      <IconLocateFixed />{{ meta.positionAutoLabel }}
    </button>
    <template v-if="meta.places.length > 0">
      <div v-if="meta.positionAutoLabel" class="moodiary-pop-divider"></div>
      <div class="flex max-h-[200px] flex-col gap-0.5 overflow-y-auto overscroll-contain">
        <button
          v-for="place in meta.places"
          :key="place.id"
          type="button"
          class="moodiary-pop-item"
          :class="{ 'is-active': place.id === meta.positionId }"
          @click="act('pickPlace', { id: place.id })"
        >
          <component :is="placeIcon(place.icon)" />
          <span class="min-w-0 flex-1 truncate">{{ place.name }}</span>
          <span v-if="place.distance" class="text-xs font-normal tabular-nums opacity-70">{{ place.distance }}</span>
        </button>
      </div>
    </template>
    <div v-if="meta.positionAutoLabel || meta.places.length > 0" class="moodiary-pop-divider"></div>
    <button type="button" class="moodiary-pop-item" @click="act('newPlace')">
      <IconPlus />{{ meta.positionNewPlaceLabel }}
    </button>
    <button type="button" class="moodiary-pop-item is-dim" @click="act('managePlaces')">
      <IconSettings />{{ meta.positionManageLabel }}
    </button>
    <button v-if="meta.position" type="button" class="moodiary-pop-item is-dim" @click="act('clearPosition')">
      <IconX />{{ meta.positionClearLabel }}
    </button>
  </Popover>
</template>
