<script setup lang="ts">
// 日记属性头（原 Flutter 侧渲染，整体搬进 webview 以随正文一起滚动）。
// 三行分层，强度四级递减：日期(粗) > 心情(彩色胶囊) > 功能(灰字图标) > 标签(浅灰 #)。
// 编辑态各项可点：原生选择器（日期/时间/分类/加标签/天气/定位）经事件回跳 Flutter，
// 心情三选与标签删除用页内 PopupMenu，不回跳。
import { computed, ref, type Component } from 'vue'
import { post } from '../bridge/post'
import type { EditorMeta } from '../bridge/meta'
import PopupMenu, { type PopupMenuItem } from './PopupMenu.vue'
import IconChevronDown from '~icons/lucide/chevron-down'
import IconSparkles from '~icons/lucide/sparkles'
import IconFrown from '~icons/lucide/frown'
import IconMeh from '~icons/lucide/meh'
import IconSmile from '~icons/lucide/smile'
import IconFolder from '~icons/lucide/folder'
import IconMapPin from '~icons/lucide/map-pin'
import IconPlus from '~icons/lucide/plus'
import IconTrash from '~icons/lucide/trash-2'
import IconCloud from '~icons/lucide/cloud'
// 和风官方图标字体：只引 woff2（?url 产出资产地址）+ JSON 码表，不 import 它的 css ——
// 那份 css 会把 woff/ttf 两种回退格式（约 270KB）一起拽进产物，且 460 条 .qi-* 规则也用不上。
import qiFontUrl from 'qweather-icons/font/fonts/qweather-icons.woff2?url'
import qiCodepoints from 'qweather-icons/font/qweather-icons.json'

const props = defineProps<{
  meta: EditorMeta
  editable: boolean
}>()

const MOOD_ICONS: Record<string, Component> = {
  negative: IconFrown,
  neutral: IconMeh,
  positive: IconSmile,
}

const currentMood = computed(
  () => props.meta.moods.find((m) => m.value === props.meta.mood) ?? props.meta.moods[0],
)
const moodIcon = computed(() => MOOD_ICONS[props.meta.mood] ?? IconMeh)

const moodMenuOpen = ref(false)
const moodMenuItems = computed<PopupMenuItem[]>(() =>
  props.meta.moods.map((m) => ({
    key: m.value,
    label: m.label,
    icon: MOOD_ICONS[m.value],
    active: m.value === props.meta.mood,
  })),
)
function onMoodSelect(key: string): void {
  post('changeMood', { mood: key })
}

// 字体注册一次（模块作用域）：编辑器 boot 即开始加载，早于 setMeta 推入，头部露出时已就绪。
const qiFace = new FontFace('qweather-icons', `url('${qiFontUrl}')`)
document.fonts.add(qiFace)
void qiFace.load().catch(() => {})

/** 和风图标码 → 字形字符；未知码返回空串（模板回退 lucide 云）。 */
const weatherGlyph = computed(() => {
  const code = props.meta.weather?.icon
  if (!code) return ''
  const cp = (qiCodepoints as Record<string, number>)[code]
  return cp ? String.fromCodePoint(cp) : ''
})

const tagMenuIndex = ref(-1)
const tagMenuItems = computed<PopupMenuItem[]>(() => [
  {
    key: 'delete',
    label: props.meta.deleteLabel,
    icon: IconTrash,
    active: false,
    destructive: true,
  },
])
function onTagSelect(index: number): void {
  post('removeTag', { index })
}

// 阅读态只列已设置项；编辑态三项常驻（未设置只剩浅图标）。
const showCategory = computed(() => props.editable || props.meta.category)
const showWeather = computed(() => props.editable || props.meta.weather)
const showPosition = computed(() => props.editable || props.meta.position)
const showFunctionRow = computed(
  () => showCategory.value || showWeather.value || showPosition.value,
)
const showTagsRow = computed(() => props.editable || props.meta.tags.length > 0)
</script>

<template>
  <div class="meta-header">
    <!-- ① 日期锚点行 -->
    <div class="meta-date-row">
      <button
        type="button"
        class="meta-plain-btn meta-date-anchor"
        :disabled="!editable"
        @mousedown.prevent
        @click="editable && post('pickDate')"
      >
        {{ meta.dateText }}
      </button>
      <button
        type="button"
        class="meta-plain-btn meta-date-sub"
        :disabled="!editable"
        @mousedown.prevent
        @click="editable && post('pickTime')"
      >
        {{ editable ? meta.subText : meta.subTextRead }}
      </button>
      <IconChevronDown v-if="editable" class="meta-date-chevron" />
      <span class="meta-spacer" />
      <PopupMenu
        v-if="editable"
        :items="moodMenuItems"
        :model-value="moodMenuOpen"
        @update:model-value="(v) => (moodMenuOpen = v)"
        @select="onMoodSelect"
      >
        <template #trigger>
          <span
            class="meta-mood-chip"
            :style="{ color: currentMood?.color, background: `${currentMood?.color}26` }"
          >
            <component :is="moodIcon" class="size-4" />
            <span class="meta-mood-label">{{ currentMood?.label }}</span>
            <IconSparkles v-if="meta.suggested" class="size-3" :title="meta.suggestedTip" />
          </span>
        </template>
      </PopupMenu>
      <span
        v-else
        class="meta-mood-chip"
        :style="{ color: currentMood?.color, background: `${currentMood?.color}26` }"
      >
        <component :is="moodIcon" class="size-4" />
        <span class="meta-mood-label">{{ currentMood?.label }}</span>
        <IconSparkles v-if="meta.suggested" class="size-3" :title="meta.suggestedTip" />
      </span>
    </div>

    <!-- ② 功能行：分类 / 天气 / 位置 -->
    <div v-if="showFunctionRow" class="meta-fn-row">
      <button
        v-if="showCategory"
        type="button"
        class="meta-plain-btn meta-fn-item"
        :disabled="!editable"
        @mousedown.prevent
        @click="editable && post('pickCategory')"
      >
        <IconFolder class="meta-fn-icon" :class="{ 'meta-fn-icon--unset': !meta.category }" />
        <span v-if="meta.category" class="meta-fn-label">{{ meta.category }}</span>
      </button>
      <button
        v-if="showWeather"
        type="button"
        class="meta-plain-btn meta-fn-item"
        :disabled="!editable"
        @mousedown.prevent
        @click="editable && post('fetchWeather')"
      >
        <span v-if="weatherGlyph" class="meta-fn-icon meta-fn-qi">{{ weatherGlyph }}</span>
        <IconCloud
          v-else
          class="meta-fn-icon"
          :class="{ 'meta-fn-icon--unset': !meta.weather }"
        />
        <span v-if="meta.weather" class="meta-fn-label">{{ meta.weather.text }}</span>
      </button>
      <button
        v-if="showPosition"
        type="button"
        class="meta-plain-btn meta-fn-item meta-fn-item--shrink"
        :disabled="!editable"
        @mousedown.prevent
        @click="editable && post('fetchPosition')"
      >
        <IconMapPin class="meta-fn-icon" :class="{ 'meta-fn-icon--unset': !meta.position }" />
        <span v-if="meta.position" class="meta-fn-label">{{ meta.position }}</span>
      </button>
    </div>

    <!-- ③ 标签行 -->
    <div v-if="showTagsRow" class="meta-tags-row">
      <template v-for="(tag, i) in meta.tags" :key="`${i}-${tag}`">
        <PopupMenu
          v-if="editable"
          :items="tagMenuItems"
          :model-value="tagMenuIndex === i"
          @update:model-value="(v) => (tagMenuIndex = v ? i : -1)"
          @select="() => onTagSelect(i)"
        >
          <template #trigger>
            <span class="meta-tag">#{{ tag }}</span>
          </template>
        </PopupMenu>
        <span v-else class="meta-tag">#{{ tag }}</span>
      </template>
      <button
        v-if="editable"
        type="button"
        class="meta-plain-btn meta-tag-add"
        @mousedown.prevent
        @click="post('addTag')"
      >
        <IconPlus class="size-3.5" />
      </button>
    </div>
  </div>
</template>

<style scoped>
.meta-header {
  flex: 0 0 auto;
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: calc(12px * var(--app-font-scale, 1)) 16px 4px;
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

/* ① 日期锚点行 */
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
.meta-spacer {
  flex: 1 0 8px;
}

/* 心情胶囊：色值来自 meta 数据（业务三色），背景 15% 透明度由内联 style 拼 8 位 hex。 */
.meta-mood-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: calc(12px * var(--app-font-scale, 1));
  font-weight: 600;
  white-space: nowrap;
  cursor: inherit;
}

/* ② 功能行 */
.meta-fn-row {
  display: flex;
  align-items: center;
  min-width: 0;
}
.meta-fn-item {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 8px 4px;
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
/* 和风字体字形：以文字渲染，宽高交给字体度量（覆盖 .meta-fn-icon 的固定宽高）。 */
.meta-fn-qi {
  width: auto;
  height: auto;
  font-family: 'qweather-icons';
  font-size: 15px;
  line-height: 1;
  font-style: normal;
  font-weight: 400;
}
.meta-fn-label {
  color: var(--app-on-surface-variant);
  font-size: calc(12px * var(--app-font-scale, 1));
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 0;
}

/* ③ 标签行 */
.meta-tags-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  column-gap: 8px;
}
.meta-tag {
  display: inline-block;
  padding: 6px 2px;
  color: var(--app-on-surface-variant);
  opacity: 0.75;
  font-size: calc(12px * var(--app-font-scale, 1));
  cursor: inherit;
}
.meta-tag-add {
  display: inline-flex;
  align-items: center;
  padding: 6px;
  color: var(--app-outline);
}
</style>
