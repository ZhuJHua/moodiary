import { ref } from 'vue'

/** 心情选项（菜单 + 胶囊共用）：值为 Flutter 侧枚举名，label/color 已由宿主解析。 */
export interface EditorMetaMoodOption {
  value: string
  label: string
  color: string
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
  /** 当前心情（枚举名 negative/neutral/positive）。 */
  mood: string
  moods: EditorMetaMoodOption[]
  /** 当前心情是否来自模型建议（胶囊带 sparkles 角标）。 */
  suggested?: boolean
  suggestedTip?: string
  category?: string | null
  weather?: { icon: string; text: string } | null
  position?: string | null
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
