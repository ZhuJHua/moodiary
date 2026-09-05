import { ref } from 'vue'

/**
 * 心情状态选项（面板 + 胶囊共用）：值为 Flutter 侧枚举名，label/color 已由宿主解析，
 * icon 是 lucide 图标名（web 侧据此查本地组件表）。
 */
export interface EditorMetaMoodOption {
  value: string
  label: string
  color: string
  icon: string
}

/**
 * 常用地点选项。icon 是 lucide 图标名；distance 是「距最近一次定位多远」（已格式化），
 * 宿主拿到定位后会按它升序重发列表，没定位过则为 null、顺序为用户手排。
 */
export interface EditorMetaPlace {
  id: string
  name: string
  icon: string
  distance?: string | null
}

/** 手选天气选项：code 是和风天气码（图标据此取字形），label 已本地化。 */
export interface EditorMetaWeatherOption {
  code: string
  label: string
}

/**
 * 日记属性头数据。所有显示串（日期格式化 / 分类名 / 字数文案）都由 Flutter 侧用
 * intl / l10n 解析好再下发 —— web 侧零本地化逻辑，只负责铺版与回传交互事件。
 */
export interface EditorMeta {
  /** 日期锚点（如 `2026/8/30`）。 */
  dateText: string
  /** 编辑态辅字（如 `周日 14:32:08`）。 */
  subText: string
  /** 阅读态辅字（含字数，如 `周日 14:32:08 · 286 字`）。 */
  subTextRead: string
  /** 当前心情/状态（枚举名，如 positive/love/slacking）。 */
  mood: string
  moods: EditorMetaMoodOption[]
  category?: string | null
  /** 当前天气；text 已由宿主拼好（手选天气没有温度，只有描述）。 */
  weather?: { icon: string; text: string } | null
  /** 手选天气的候选集（16 个和风码，4×4 一屏）。 */
  weatherOptions: EditorMetaWeatherOption[]
  /** 「自动获取」文案；**null = 和风未配置**，那一条整个不渲染。 */
  weatherAutoLabel?: string | null
  weatherClearLabel: string
  /** 当前地点的展示名（日记引用常用地点，名字随地点改）。 */
  position?: string | null
  /** 当前地点 id，列表按它高亮。 */
  positionId?: string | null
  /** 常用地点列表；空数组则面板里不出现这一段。顺序由宿主决定，web 不排序。 */
  places: EditorMetaPlace[]
  /** 「自动获取」（和风反查）文案；**null = 和风未配置**，那一条整个不渲染。 */
  positionAutoLabel?: string | null
  positionNewPlaceLabel: string
  positionManageLabel: string
  positionClearLabel: string
  tags: string[]
  /** 标签删除菜单条目文案。 */
  deleteLabel: string
}

export interface EditorLinkItem {
  id: string
  title: string
  subtitle?: string
}

/** 文末双链面板数据（仅阅读态渲染）；文案同样由 Flutter 解析好下发。 */
export interface EditorLinks {
  title: string
  outgoingLabel: string
  incomingLabel: string
  graphTip?: string
  outgoing: EditorLinkItem[]
  incoming: EditorLinkItem[]
}

export const meta = ref<EditorMeta | null>(null)

export const links = ref<EditorLinks | null>(null)

export function setMeta(json: string): void {
  try {
    meta.value = json ? (JSON.parse(json) as EditorMeta) : null
  } catch {
    meta.value = null
  }
}

export function setLinks(json: string): void {
  try {
    links.value = json ? (JSON.parse(json) as EditorLinks) : null
  } catch {
    links.value = null
  }
}
