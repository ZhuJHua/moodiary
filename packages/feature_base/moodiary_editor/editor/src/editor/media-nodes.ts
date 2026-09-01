// 音频 / 视频自定义节点（block atom：叶子、整体可选）。存储走 TipTap JSON，节点 attrs.filename
// 直接随 JSON 无损存取 —— 无需 markdown 序列化约定，也无需按文件名前缀路由（那是上一版 markdown
// 存储的权宜之计，已随 JSON 存储移除）。显示由 Vue node view（components/nodes/*）渲染，并在
// webview 内用原生 <audio>/<video> 内联播放（不再委托 Flutter 原生）。parseHTML/renderHTML 仅供剪贴板 / HTML 粘贴兜底；
// JSON 加载经节点 type 直接重建，不走 HTML 解析。
//
// draggable=false：播放器内含原生 <input type=range> 进度条，节点若可拖会把进度条上的指针拖拽
// 误判为整块拖动，故关掉拖动（atom+selectable 仍可整块选中/删除）。

import { Node, mergeAttributes } from '@tiptap/core'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import type { Component } from 'vue'
import AudioNodeView from '../components/nodes/AudioNodeView.vue'
import VideoNodeView from '../components/nodes/VideoNodeView.vue'

function createMediaNode(opts: { name: string; view: Component }): Node {
  return Node.create({
    name: opts.name,
    group: 'block',
    atom: true,
    draggable: false,
    selectable: true,
    addAttributes() {
      return {
        // 裸文件名（audio-* / video-*）。剪贴板 HTML 形态用 data-filename 承载。
        filename: {
          default: null,
          parseHTML: (el) => el.getAttribute('data-filename'),
          renderHTML: (attrs) => (attrs.filename ? { 'data-filename': attrs.filename } : {}),
        },
      }
    },
    parseHTML() {
      return [{ tag: `div[data-media="${opts.name}"]` }]
    },
    renderHTML({ HTMLAttributes }) {
      return ['div', mergeAttributes(HTMLAttributes, { 'data-media': opts.name })]
    },
    addNodeView() {
      return VueNodeViewRenderer(opts.view)
    },
  })
}

export const Audio = createMediaNode({ name: 'audio', view: AudioNodeView })
export const Video = createMediaNode({ name: 'video', view: VideoNodeView })
