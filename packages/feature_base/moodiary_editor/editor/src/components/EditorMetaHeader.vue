<script setup lang="ts">
// 日记属性头（原 Flutter 侧渲染，整体搬进 webview 以随正文一起滚动）。
// 三行分层，强度四级递减：日期(粗) > 心情(彩色胶囊) > 功能(灰字图标) > 标签(浅灰 #)。
// 编辑态各项可点：原生选择器（日期/时间/分类/加标签/天气/定位）经事件回跳 Flutter，
// 心情状态面板（平铺网格）与标签删除用页内 PopupMenu，不回跳。
import { computed, ref, type Component } from 'vue'
import { post } from '../bridge/post'
import type { EditorMeta } from '../bridge/meta'
import PopupMenu, { type PopupMenuItem } from './PopupMenu.vue'
import IconChevronDown from '~icons/lucide/chevron-down'
import IconSmile from '~icons/lucide/smile'
import IconMeh from '~icons/lucide/meh'
import IconFrown from '~icons/lucide/frown'
import IconSparkles from '~icons/lucide/sparkles'
import IconAngry from '~icons/lucide/angry'
import IconTornado from '~icons/lucide/tornado'
import IconBatteryLow from '~icons/lucide/battery-low'
import IconAnnoyed from '~icons/lucide/annoyed'
import IconHeart from '~icons/lucide/heart'
import IconBookOpen from '~icons/lucide/book-open'
import IconFish from '~icons/lucide/fish'
import IconUtensils from '~icons/lucide/utensils'
import IconBriefcase from '~icons/lucide/briefcase'
import IconPlane from '~icons/lucide/plane'
import IconDumbbell from '~icons/lucide/dumbbell'
import IconThermometer from '~icons/lucide/thermometer'
import IconFolder from '~icons/lucide/folder'
import IconMapPin from '~icons/lucide/map-pin'
import IconPlus from '~icons/lucide/plus'
import IconTrash from '~icons/lucide/trash-2'
import IconCloud from '~icons/lucide/cloud'
import IconRefresh from '~icons/lucide/refresh-cw'
import IconX from '~icons/lucide/x'
import IconLocateFixed from '~icons/lucide/locate-fixed'
import IconSettings from '~icons/lucide/settings'
import IconHouse from '~icons/lucide/house'
import IconBuilding from '~icons/lucide/building-2'
import IconSchool from '~icons/lucide/school'
import IconCoffee from '~icons/lucide/coffee'
import IconTrees from '~icons/lucide/trees'
import IconHospital from '~icons/lucide/hospital'
// 和风官方图标字体：只引 woff2（?url 产出资产地址）+ JSON 码表，不 import 它的 css ——
// 那份 css 会把 woff/ttf 两种回退格式（约 270KB）一起拽进产物，且 460 条 .qi-* 规则也用不上。
import qiFontUrl from 'qweather-icons/font/fonts/qweather-icons.woff2?url'
import qiCodepoints from 'qweather-icons/font/qweather-icons.json'

const props = defineProps<{
  meta: EditorMeta
  editable: boolean
}>()

// 键 = 契约里的 lucide 图标名（EditorMetaMoodOption.icon）。
const MOOD_ICONS: Record<string, Component> = {
  smile: IconSmile,
  meh: IconMeh,
  frown: IconFrown,
  sparkles: IconSparkles,
  angry: IconAngry,
  tornado: IconTornado,
  'battery-low': IconBatteryLow,
  annoyed: IconAnnoyed,
  heart: IconHeart,
  'book-open': IconBookOpen,
  fish: IconFish,
  utensils: IconUtensils,
  briefcase: IconBriefcase,
  plane: IconPlane,
  dumbbell: IconDumbbell,
  thermometer: IconThermometer,
}

// 常用地点的图标：契约里给 lucide 名，未知名回退图钉。
const PLACE_ICONS: Record<string, Component> = {
  house: IconHouse,
  'building-2': IconBuilding,
  school: IconSchool,
  coffee: IconCoffee,
  dumbbell: IconDumbbell,
  trees: IconTrees,
  hospital: IconHospital,
  plane: IconPlane,
  'map-pin': IconMapPin,
}

const currentMood = computed(
  () => props.meta.moods.find((m) => m.value === props.meta.mood) ?? props.meta.moods[0],
)
const moodIcon = computed(() => MOOD_ICONS[currentMood.value?.icon ?? ''] ?? IconMeh)

const moodMenuOpen = ref(false)
function onMoodSelect(key: string): void {
  moodMenuOpen.value = false
  post('changeMood', { mood: key })
}

// 字体注册一次（模块作用域）：编辑器 boot 即开始加载，早于 setMeta 推入，头部露出时已就绪。
const qiFace = new FontFace('qweather-icons', `url('${qiFontUrl}')`)
document.fonts.add(qiFace)
void qiFace.load().catch(() => {})

/** 和风图标码 → 字形字符；未知码返回空串（模板回退 lucide 云）。 */
function glyphOf(code: string | undefined | null): string {
  if (!code) return ''
  const cp = (qiCodepoints as Record<string, number>)[code]
  return cp ? String.fromCodePoint(cp) : ''
}

const weatherGlyph = computed(() => glyphOf(props.meta.weather?.icon))

const weatherMenuOpen = ref(false)
function onWeatherSelect(code: string): void {
  weatherMenuOpen.value = false
  post('changeWeather', { code })
}
function onWeatherAuto(): void {
  weatherMenuOpen.value = false
  post('fetchWeather')
}
function onWeatherClear(): void {
  weatherMenuOpen.value = false
  post('clearWeather')
}

const positionMenuOpen = ref(false)
// 点位置总是开面板（与心情 / 天气一致）。开面板那一刻让宿主取一次定位：常用地点按
// 「距此多远」排序、「存为常用地点」也靠这次坐标——不取就只是手排顺序、没有距离。
function onPositionMenuToggle(open: boolean): void {
  positionMenuOpen.value = open
  if (open) post('locateForPlaces')
}
function onPositionAction(type: string, payload?: unknown): void {
  positionMenuOpen.value = false
  post(type, payload)
}

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

// 阅读态只列已设置项；编辑态三项常驻（未设置只剩浅图标）。心情必有值，功能行恒显。
const showCategory = computed(() => props.editable || props.meta.category)
const showWeather = computed(() => props.editable || props.meta.weather)
const showPosition = computed(() => props.editable || props.meta.position)
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
    </div>

    <!-- ② 功能行：心情 / 分类 / 天气 / 位置 -->
    <div class="meta-fn-row">
      <PopupMenu
        v-if="editable"
        class="meta-fn-mood"
        :model-value="moodMenuOpen"
        @update:model-value="(v) => (moodMenuOpen = v)"
      >
        <template #trigger>
          <span
            class="meta-mood-chip"
            :style="{ color: currentMood?.color, background: `${currentMood?.color}26` }"
          >
            <component :is="moodIcon" class="size-4" />
            <span class="meta-mood-label">{{ currentMood?.label }}</span>
          </span>
        </template>
        <template #panel>
          <div class="mood-panel">
            <div class="mood-grid">
              <button
                v-for="m in meta.moods"
                :key="m.value"
                type="button"
                class="mood-cell"
                :class="{ 'mood-cell--active': m.value === meta.mood }"
                :style="
                  m.value === meta.mood
                    ? { color: m.color, background: `${m.color}26` }
                    : undefined
                "
                @mousedown.prevent
                @click.stop="onMoodSelect(m.value)"
              >
                <component :is="MOOD_ICONS[m.icon] ?? IconMeh" class="mood-cell-icon" />
                <span class="mood-cell-label">{{ m.label }}</span>
              </button>
            </div>
          </div>
        </template>
      </PopupMenu>
      <span
        v-else
        class="meta-fn-mood meta-mood-chip"
        :style="{ color: currentMood?.color, background: `${currentMood?.color}26` }"
      >
        <component :is="moodIcon" class="size-4" />
        <span class="meta-mood-label">{{ currentMood?.label }}</span>
      </span>
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
      <PopupMenu
        v-if="editable && showWeather"
        class="meta-fn-weather"
        :model-value="weatherMenuOpen"
        @update:model-value="(v) => (weatherMenuOpen = v)"
      >
        <template #trigger>
          <span class="meta-fn-item" @mousedown.prevent>
            <span v-if="weatherGlyph" class="meta-fn-icon meta-fn-qi">{{ weatherGlyph }}</span>
            <IconCloud
              v-else
              class="meta-fn-icon"
              :class="{ 'meta-fn-icon--unset': !meta.weather }"
            />
            <span v-if="meta.weather" class="meta-fn-label">{{ meta.weather.text }}</span>
          </span>
        </template>
        <template #panel>
          <div class="weather-panel">
            <div class="weather-grid">
              <button
                v-for="w in meta.weatherOptions"
                :key="w.code"
                type="button"
                class="weather-cell"
                :class="{ 'weather-cell--active': w.code === meta.weather?.icon }"
                @mousedown.prevent
                @click.stop="onWeatherSelect(w.code)"
              >
                <span class="weather-cell-icon">{{ glyphOf(w.code) }}</span>
                <span class="weather-cell-label">{{ w.label }}</span>
              </button>
            </div>
            <!-- 和风没配好时 weatherAutoLabel 为 null，整条不渲染（点了也只会失败） -->
            <template v-if="meta.weatherAutoLabel || meta.weather">
              <div class="weather-divider"></div>
              <button
                v-if="meta.weatherAutoLabel"
                type="button"
                class="weather-action"
                @mousedown.prevent
                @click.stop="onWeatherAuto()"
              >
                <IconRefresh class="weather-action-icon" />
                <span>{{ meta.weatherAutoLabel }}</span>
              </button>
              <button
                v-if="meta.weather"
                type="button"
                class="weather-action weather-action--dim"
                @mousedown.prevent
                @click.stop="onWeatherClear()"
              >
                <IconX class="weather-action-icon" />
                <span>{{ meta.weatherClearLabel }}</span>
              </button>
            </template>
          </div>
        </template>
      </PopupMenu>
      <span v-else-if="showWeather" class="meta-fn-item">
        <span v-if="weatherGlyph" class="meta-fn-icon meta-fn-qi">{{ weatherGlyph }}</span>
        <IconCloud v-else class="meta-fn-icon meta-fn-icon--unset" />
        <span v-if="meta.weather" class="meta-fn-label">{{ meta.weather.text }}</span>
      </span>
      <PopupMenu
        v-if="editable && showPosition"
        class="meta-fn-position"
        :model-value="positionMenuOpen"
        @update:model-value="onPositionMenuToggle"
      >
        <template #trigger>
          <span class="meta-fn-item meta-fn-item--shrink" @mousedown.prevent>
            <IconMapPin
              class="meta-fn-icon"
              :class="{ 'meta-fn-icon--unset': !meta.position }"
            />
            <span v-if="meta.position" class="meta-fn-label">{{ meta.position }}</span>
          </span>
        </template>
        <template #panel>
          <div class="place-panel">
            <!-- 和风没配好时 positionAutoLabel 为 null，整条不渲染（同天气面板） -->
            <button
              v-if="meta.positionAutoLabel"
              type="button"
              class="place-action"
              @mousedown.prevent
              @click.stop="onPositionAction('fetchPosition')"
            >
              <IconLocateFixed class="place-action-icon" />
              <span>{{ meta.positionAutoLabel }}</span>
            </button>
            <template v-if="meta.places.length > 0">
              <div v-if="meta.positionAutoLabel" class="place-divider"></div>
              <div class="place-list">
                <button
                  v-for="place in meta.places"
                  :key="place.id"
                  type="button"
                  class="place-row"
                  :class="{ 'place-row--active': place.id === meta.positionId }"
                  @mousedown.prevent
                  @click.stop="onPositionAction('pickPlace', { id: place.id })"
                >
                  <component
                    :is="PLACE_ICONS[place.icon] ?? IconMapPin"
                    class="place-row-icon"
                  />
                  <span class="place-row-name">{{ place.name }}</span>
                  <span v-if="place.distance" class="place-row-distance">
                    {{ place.distance }}
                  </span>
                </button>
              </div>
            </template>
            <div
              v-if="meta.positionAutoLabel || meta.places.length > 0"
              class="place-divider"
            ></div>
            <button
              type="button"
              class="place-action"
              @mousedown.prevent
              @click.stop="onPositionAction('newPlace')"
            >
              <IconPlus class="place-action-icon" />
              <span>{{ meta.positionNewPlaceLabel }}</span>
            </button>
            <button
              type="button"
              class="place-action place-action--dim"
              @mousedown.prevent
              @click.stop="onPositionAction('managePlaces')"
            >
              <IconSettings class="place-action-icon" />
              <span>{{ meta.positionManageLabel }}</span>
            </button>
            <button
              v-if="meta.position"
              type="button"
              class="place-action place-action--dim"
              @mousedown.prevent
              @click.stop="onPositionAction('clearPosition')"
            >
              <IconX class="place-action-icon" />
              <span>{{ meta.positionClearLabel }}</span>
            </button>
          </div>
        </template>
      </PopupMenu>
      <span v-else-if="showPosition" class="meta-fn-item meta-fn-item--shrink">
        <IconMapPin class="meta-fn-icon meta-fn-icon--unset" />
        <span v-if="meta.position" class="meta-fn-label">{{ meta.position }}</span>
      </span>
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
/* 属性头 / 标题 / 正文三段共用 16px 左边线；下边距交给标题的 padding-top 统一给，
   这里给 0 —— 两处各留一半会让「属性头到标题」比「标题到正文」还宽。 */
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

/* 心情胶囊：色值来自 meta 数据（业务色），背景 15% 透明度由内联 style 拼 8 位 hex。 */
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
.meta-fn-mood {
  flex: none;
  margin-right: 10px;
}
/* PopupMenu 的宿主 div 是功能行里的一个 flex 项，天气标签长了要能收窄。 */
.meta-fn-weather,
.meta-fn-position {
  flex: 0 1 auto;
  min-width: 0;
}

/* 心情状态面板：4 列平铺网格，格子 = 图标 + 标签，选中格用该态语义色高亮。 */
.mood-panel {
  width: 276px;
  padding-top: 4px;
}
.mood-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 2px;
}
.mood-cell {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 8px 2px 6px;
  border: none;
  border-radius: 12px;
  background: transparent;
  color: var(--app-on-surface);
  font-family: inherit;
  cursor: pointer;
  outline: none;
  -webkit-tap-highlight-color: transparent;
}
.mood-cell:hover {
  background: var(--app-selected);
}
.mood-cell--active {
  font-weight: 600;
}
.mood-cell-icon {
  width: 20px;
  height: 20px;
}
.mood-cell-label {
  font-size: 11px;
  white-space: nowrap;
}

/* 天气面板：与心情面板同一栅格（4 列、gap 2、格子 radius 12），图标换成和风字形。
   选中态用 secondaryContainer —— 天气没有心情那样的语义色，借它的会误导。 */
.weather-panel {
  width: 276px;
  padding-top: 4px;
}
.weather-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 2px;
}
.weather-cell {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 8px 2px 6px;
  border: none;
  border-radius: 12px;
  background: transparent;
  color: var(--app-on-surface);
  font-family: inherit;
  cursor: pointer;
  outline: none;
  -webkit-tap-highlight-color: transparent;
}
.weather-cell:hover {
  background: var(--app-selected);
}
.weather-cell--active {
  background: var(--app-secondary);
  color: var(--app-on-secondary);
  font-weight: 600;
}
.weather-cell--active:hover {
  background: var(--app-secondary);
}
.weather-cell-icon {
  font-family: 'qweather-icons';
  font-size: 20px;
  line-height: 1;
  font-style: normal;
  font-weight: 400;
}
.weather-cell-label {
  font-size: 11px;
  white-space: nowrap;
}
.weather-divider {
  height: 1px;
  background: var(--app-outline);
  margin: 5px 10px;
}
.weather-action {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 10px 12px;
  border: none;
  border-radius: 12px;
  background: transparent;
  color: var(--app-on-surface);
  font-family: inherit;
  font-size: 14px;
  font-weight: 500;
  text-align: left;
  cursor: pointer;
  outline: none;
  -webkit-tap-highlight-color: transparent;
}
.weather-action:hover {
  background: var(--app-selected);
}
.weather-action--dim {
  color: var(--app-on-surface-variant);
}
.weather-action-icon {
  width: 19px;
  height: 19px;
  flex: none;
}

/* 位置面板：一列条目，与 PopupMenu 默认条目同规格（radius 12、14px 中等字重）。
   预设行多一列距离，右对齐、等宽数字，免得 120 m / 4.2 km 抖动。 */
.place-panel {
  width: 236px;
  padding-top: 2px;
}
.place-list {
  display: flex;
  flex-direction: column;
  gap: 2px;
  max-height: 200px;
  overflow-y: auto;
}
.place-row,
.place-action {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 9px 12px;
  border: none;
  border-radius: 12px;
  background: transparent;
  color: var(--app-on-surface);
  font-family: inherit;
  font-size: 14px;
  font-weight: 500;
  text-align: left;
  cursor: pointer;
  outline: none;
  -webkit-tap-highlight-color: transparent;
}
.place-row:hover,
.place-action:hover {
  background: var(--app-selected);
}
.place-row--active {
  background: var(--app-secondary);
  color: var(--app-on-secondary);
}
.place-row--active:hover {
  background: var(--app-secondary);
}
.place-row-icon,
.place-action-icon {
  width: 19px;
  height: 19px;
  flex: none;
}
.place-row-name {
  flex: 1 1 auto;
  min-width: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.place-row-distance {
  flex: none;
  font-size: 12px;
  font-weight: 400;
  font-variant-numeric: tabular-nums;
  color: var(--app-on-surface-variant);
}
.place-row--active .place-row-distance {
  color: inherit;
}
.place-action--dim {
  color: var(--app-on-surface-variant);
}
.place-divider {
  height: 1px;
  background: var(--app-outline);
  margin: 5px 10px;
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
/* 负边距抵掉 .meta-tag 自己的 2px 横向内边距，让「#」与标题、正文对齐同一条左边线。 */
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
  cursor: inherit;
}
.meta-tag-add {
  display: inline-flex;
  align-items: center;
  padding: 6px;
  color: var(--app-outline);
}
</style>
