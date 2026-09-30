<script setup lang="ts">
import { computed, ref } from 'vue'
import { post } from '../bridge/post'
import type { EditorMeta } from '../bridge/meta'
import IconChevronDown from '~icons/lucide/chevron-down'
import IconFolder from '~icons/lucide/folder'
import IconMapPin from '~icons/lucide/map-pin'
import IconPlus from '~icons/lucide/plus'
import IconCloud from '~icons/lucide/cloud'
import IconTrash from '~icons/lucide/trash-2'
import Popover from './ui/Popover.vue'
import MoodPicker from './meta/MoodPicker.vue'
import WeatherPicker from './meta/WeatherPicker.vue'
import PlacePicker from './meta/PlacePicker.vue'
import CategoryPicker from './meta/CategoryPicker.vue'
import DatePicker from './meta/DatePicker.vue'
import TimePicker from './meta/TimePicker.vue'
import { moodIcon, weatherGlyph } from './meta/icons'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  meta: EditorMeta
  editable: boolean
  wordCount: number
}>()

const { t } = useI18n()

const subLine = computed(() =>
  props.editable
    ? props.meta.subText
    : `${props.meta.subText} · ${t('wordCount', { count: props.wordCount })}`,
)

const currentMood = computed(
  () => props.meta.moods.find((m) => m.value === props.meta.mood) ?? props.meta.moods[0],
)
const weatherIcon = computed(() => weatherGlyph(props.meta.weather?.icon))

const moodPicker = ref<InstanceType<typeof MoodPicker>>()
const weatherPicker = ref<InstanceType<typeof WeatherPicker>>()
const placePicker = ref<InstanceType<typeof PlacePicker>>()
const categoryPicker = ref<InstanceType<typeof CategoryPicker>>()
const datePicker = ref<InstanceType<typeof DatePicker>>()
const timePicker = ref<InstanceType<typeof TimePicker>>()
const tagMenu = ref<InstanceType<typeof Popover>>()
const tagTarget = ref('')
const tagDraft = ref('')

const anchorOf = (e: Event): HTMLElement => e.currentTarget as HTMLElement

function openTag(tag: string, e: Event): void {
  tagTarget.value = tag
  tagMenu.value?.open(anchorOf(e))
}

function removeTag(): void {
  tagMenu.value?.close()
  post('removeTag', { name: tagTarget.value })
}

function onTagInput(e: Event): void {
  tagDraft.value = (e.target as HTMLInputElement).value
}

function onTagEnter(e: KeyboardEvent): void {
  if (e.isComposing) return
  e.preventDefault()
  const input = e.target as HTMLInputElement
  const name = input.value.trim()
  input.value = ''
  tagDraft.value = ''
  if (name && !props.meta.tags.includes(name)) post('addTag', { name })
}

const showCategory = computed(() => props.editable || props.meta.category)
const showWeather = computed(() => props.editable || props.meta.weather)
const showPosition = computed(() => props.editable || props.meta.position)
const showTagsRow = computed(() => props.editable || props.meta.tags.length > 0)
</script>

<template>
  <div class="meta-header">
    <div class="meta-date-row">
      <button
        type="button"
        class="meta-plain-btn meta-date-anchor"
        :disabled="!editable"
        @mousedown.prevent
        @click="datePicker?.open(anchorOf($event))"
      >
        {{ meta.dateText }}
      </button>
      <button
        type="button"
        class="meta-plain-btn meta-date-sub"
        :disabled="!editable"
        @mousedown.prevent
        @click="timePicker?.open(anchorOf($event))"
      >
        {{ subLine }}
      </button>
      <IconChevronDown v-if="editable" class="meta-date-chevron" />
    </div>

    <div class="meta-fn-row">
      <button
        type="button"
        class="meta-plain-btn meta-fn-mood meta-mood-chip"
        :style="{ color: currentMood?.color, background: `${currentMood?.color}26` }"
        :disabled="!editable"
        @mousedown.prevent
        @click="moodPicker?.open(anchorOf($event))"
      >
        <component :is="moodIcon(currentMood?.icon)" class="size-4" />
        <span class="meta-mood-label">{{ currentMood?.label }}</span>
      </button>
      <button
        v-if="showCategory"
        type="button"
        class="meta-plain-btn meta-fn-item"
        :disabled="!editable"
        @mousedown.prevent
        @click="categoryPicker?.open(anchorOf($event))"
      >
        <IconFolder class="meta-fn-icon" :class="{ 'meta-fn-icon--unset': !meta.category }" />
        <span v-if="meta.category" class="meta-fn-label">{{ meta.category }}</span>
      </button>
      <button
        v-if="showWeather"
        type="button"
        class="meta-plain-btn meta-fn-item meta-fn-item--shrink"
        :disabled="!editable"
        @mousedown.prevent
        @click="weatherPicker?.open(anchorOf($event))"
      >
        <span v-if="weatherIcon" class="meta-fn-icon meta-fn-qi">{{ weatherIcon }}</span>
        <IconCloud v-else class="meta-fn-icon" :class="{ 'meta-fn-icon--unset': !meta.weather }" />
        <span v-if="meta.weather" class="meta-fn-label">{{ meta.weather.text }}</span>
      </button>
      <button
        v-if="showPosition"
        type="button"
        class="meta-plain-btn meta-fn-item meta-fn-item--shrink"
        :disabled="!editable"
        @mousedown.prevent
        @click="placePicker?.open(anchorOf($event))"
      >
        <IconMapPin class="meta-fn-icon" :class="{ 'meta-fn-icon--unset': !meta.position }" />
        <span v-if="meta.position" class="meta-fn-label">{{ meta.position }}</span>
      </button>
    </div>

    <div v-if="showTagsRow" class="meta-tags-row">
      <button
        v-for="(tag, i) in meta.tags"
        :key="`${i}-${tag}`"
        type="button"
        class="meta-plain-btn meta-tag"
        :disabled="!editable"
        @mousedown.prevent
        @click="openTag(tag, $event)"
      >
        #{{ tag }}
      </button>
      <label v-if="editable" class="meta-tag-new" :class="{ 'is-filled': tagDraft }">
        <IconPlus class="meta-tag-new-icon" />
        <input
          class="meta-tag-input"
          type="text"
          enterkeyhint="done"
          :placeholder="t('meta.tagPlaceholder')"
          :aria-label="t('meta.addTag')"
          @input="onTagInput"
          @keydown.enter="onTagEnter"
        />
      </label>
    </div>

    <template v-if="editable">
      <DatePicker ref="datePicker" :meta="meta" />
      <TimePicker ref="timePicker" :meta="meta" />
      <MoodPicker ref="moodPicker" :meta="meta" />
      <CategoryPicker ref="categoryPicker" :meta="meta" />
      <WeatherPicker ref="weatherPicker" :meta="meta" />
      <PlacePicker ref="placePicker" :meta="meta" />
      <Popover ref="tagMenu" panel-class="min-w-42">
        <button type="button" class="moodiary-pop-item is-danger" @click="removeTag">
          <IconTrash />{{ t('meta.removeTag') }}
        </button>
      </Popover>
    </template>
  </div>
</template>

<style scoped>
.meta-header {
  flex: 0 0 auto;
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: calc(12px * var(--app-font-scale, 1)) 16px 0;
  font-family: var(--app-font-sans);
}

.meta-plain-btn {
  margin: 0;
  padding: 0;
  border: none;
  background: transparent;
  font-family: inherit;
  text-align: left;
  cursor: pointer;
  outline: none;
  -webkit-tap-highlight-color: transparent;
}
.meta-plain-btn:disabled {
  cursor: default;
}

.meta-date-row {
  display: flex;
  align-items: center;
  min-width: 0;
}
.meta-date-anchor {
  color: var(--app-on-background);
  font-size: calc(20px * var(--app-font-scale, 1));
  font-weight: 700;
  line-height: 1.3;
}
.meta-date-sub {
  margin-left: 6px;
  padding-bottom: 2px;
  align-self: flex-end;
  color: var(--app-on-surface-variant);
  font-size: calc(12px * var(--app-font-scale, 1));
  line-height: 1.4;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 0;
  flex: 0 1 auto;
}
.meta-date-chevron {
  width: 14px;
  height: 14px;
  margin: 0 0 4px 2px;
  align-self: flex-end;
  flex: none;
  color: var(--app-on-surface-variant);
  opacity: 0.7;
}

/* 内联 style 拼的 8 位 hex 尾码 26 = 约 15% 透明度 */
.meta-mood-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: calc(12px * var(--app-font-scale, 1));
  font-weight: 600;
  white-space: nowrap;
}
.meta-fn-mood {
  flex: none;
  margin-right: 10px;
}

.meta-fn-row {
  display: flex;
  align-items: center;
  min-width: 0;
}
.meta-fn-item {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 6px 4px;
  min-width: 0;
  margin-right: 8px;
}
.meta-fn-item--shrink {
  flex: 0 1 auto;
}
.meta-fn-icon {
  width: 15px;
  height: 15px;
  flex: none;
  color: var(--app-on-surface-variant);
  opacity: 0.85;
}
.meta-fn-icon--unset {
  color: var(--app-outline);
  opacity: 1;
}
.meta-fn-qi {
  display: grid;
  place-items: center;
  font-family: 'qweather-icons';
  font-size: 15px;
  line-height: 1;
  font-style: normal;
  font-weight: 400;
}
.meta-fn-label {
  color: var(--app-on-surface-variant);
  font-size: calc(12px * var(--app-font-scale, 1));
  line-height: 15px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 0;
}

.meta-tags-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  column-gap: 8px;
  margin-left: -2px;
}
.meta-tag {
  display: inline-block;
  padding: 6px 2px;
  color: var(--app-on-surface-variant);
  opacity: 0.75;
  font-size: calc(12px * var(--app-font-scale, 1));
}
.meta-tag-new {
  position: relative;
  display: inline-flex;
  align-items: center;
  color: var(--app-outline);
}
.meta-tag-new-icon {
  position: absolute;
  left: 6px;
  width: 14px;
  height: 14px;
  pointer-events: none;
}
.meta-tag-input {
  width: 26px;
  padding: 6px 0 6px 24px;
  border: none;
  outline: none;
  background: transparent;
  color: var(--app-on-surface-variant);
  font: inherit;
  font-size: calc(12px * var(--app-font-scale, 1));
  transition: width 0.15s ease;
}
.meta-tag-input::placeholder {
  color: transparent;
}
.meta-tag-input:focus,
.meta-tag-new.is-filled .meta-tag-input {
  width: 8rem;
}
.meta-tag-input:focus::placeholder {
  color: var(--app-outline);
}
</style>
