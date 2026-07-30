// 自定义 Image：在官方 extension-image 上加两件事 ——
// ① attr.src 永远是裸文件名（JSON 落库即裸名），仅显示时拼上媒体服务前缀（前缀每次启动随机）；
// ② widthPercent：占正文列宽的百分比上限，null = 默认（图片原始宽度，上限满栏）。
//
// 存百分比而非像素：同一篇日记在不同屏宽的设备上表现一致，参照系就是 CSS % 天然的包含块，
// 不必注入列宽变量；也不受「入库前压缩到 1280」改写原始宽高的影响。null 与「铺满」不等价 ——
// 小图铺满会被拉糊，故默认档不是 100 而是「不限」，旧日记（无该 attr）像素级零回归。
//
// 尺寸 UI 在 ImageNodeView（右下角标 → daisyUI range 滑块，无极可停但档位磁吸）。注册 node view
// 后 renderHTML 不再参与可编辑视图的 DOM 构建，但仍供剪贴板 / HTML 序列化，故两处都走 displaySrc。
import { mergeAttributes } from '@tiptap/core'
import Image from '@tiptap/extension-image'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import ImageNodeView from '../components/nodes/ImageNodeView.vue'
import { displaySrc, unproxyMedia } from './media'

/** 滑块下限。取 25 而非更小：档位正好四等分到 100，刻度行用 justify-between 就能对齐滑轨。 */
export const MIN_IMAGE_PERCENT = 25

/** 磁吸档位（也是刻度行的标签）。 */
export const IMAGE_SIZE_STOPS: readonly number[] = [25, 50, 75, 100]

/** 磁吸半径：落在档位 ±3 内就吸附，其余位置无极可停。 */
const SNAP_TOLERANCE = 3

/** 粘贴 HTML 等外部来源可能带任意值，收口到 [25,100] 整数。 */
export function clampWidthPercent(value: number): number {
  return Math.min(100, Math.max(MIN_IMAGE_PERCENT, Math.round(value)))
}

/** 拖动落点 → 实际写入值：靠近档位就吸过去，否则原样。 */
export function snapWidthPercent(value: number): number {
  const clamped = clampWidthPercent(value)
  const hit = IMAGE_SIZE_STOPS.find((stop) => Math.abs(clamped - stop) <= SNAP_TOLERANCE)
  return hit ?? clamped
}

export const MediaImage = Image.extend({
  // node view 接管 DOM 后，PM 的整块拖动会跟角标的指针事件打架（audio/video 同理）；
  // 且 HTML5 DnD 在移动端本就不可用。
  draggable: false,

  addAttributes() {
    return {
      ...this.parent?.(),
      // renderHTML 出去时拼了前缀，解析回来就必须剥掉，否则「编辑器内复制粘贴一张图」会把
      // 带随机端口的绝对 URL 落库：下次冷启动端口变了就永久裂图，且 Dart 侧把这串 URL 当文件名
      // 收进 imageName —— 原文件从此不被任何日记引用，孤儿清理会把磁盘上的真图物理删掉。
      src: {
        default: null,
        parseHTML: (el) => unproxyMedia(el.getAttribute('src') ?? ''),
      },
      // 尺寸只由 widthPercent 表达。放任 width/height 往返，复制到外部的 <img> 上会同时出现
      // width="300" 和 style="width:50%" 两套互相矛盾的宽度。
      width: { default: null, rendered: false, parseHTML: () => null },
      height: { default: null, rendered: false, parseHTML: () => null },
      widthPercent: {
        default: null,
        parseHTML: (el) => {
          const raw = el.getAttribute('data-width-percent')
          if (raw === null) return null
          const n = Number(raw)
          return Number.isFinite(n) ? clampWidthPercent(n) : null
        },
        renderHTML: (attrs) => {
          const v = attrs.widthPercent
          if (typeof v !== 'number') return {}
          // max-width 而非 width：与 node view 的语义保持一致（档位是上限，小图不被拉伸），
          // 否则复制到外部编辑器的那份 HTML 会按另一套规则渲染。
          return { 'data-width-percent': String(v), style: `max-width: ${v}%` }
        },
      },
    }
  },

  renderHTML({ HTMLAttributes }) {
    const attrs = { ...HTMLAttributes }
    if (typeof attrs.src === 'string') attrs.src = displaySrc(attrs.src)
    return ['img', mergeAttributes(this.options.HTMLAttributes, attrs)]
  },

  addNodeView() {
    return VueNodeViewRenderer(ImageNodeView)
  },
})
