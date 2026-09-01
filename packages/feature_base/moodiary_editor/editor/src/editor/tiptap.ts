// MoodiaryEditor 的 TipTap 接入。编辑器实例由 @tiptap/vue-3 的 useEditor 在 MoodiaryEditor.vue
// 里创建（生命周期随组件；且让 video/audio/未来自定义块的 Vue node view 拿到 app 上下文）。
// 本模块产出「kit」：给 useEditor 的 options + 与 bridge 约定的命令式 [EditorApi]，共享一份闭包状态。
//
// 存储 = TipTap 文档 JSON（editor.getJSON()）。自定义块（图片/音频/视频/未来卡片…）是一等节点，
// attrs 随 JSON 无损存取，无需任何 markdown 序列化约定或文件名前缀路由。tiptap-markdown 仅留作
// 「打开旧 markdown 文本日记（只读查看）」——旧 markdown / AI 生成 md → tiptap JSON 的转换已改为
// Dart 侧（MarkdownToTiptap），不再经无头编辑器。配色全部走 CSS（消费 --app-* token）。
//
// 媒体只存裸文件名（image 节点 attr.src、audio/video 节点 attr.filename 都是裸名，故 JSON 落库即裸名，
// 与每次启动随机变化的媒体服务前缀无关）；显示时由 image 的 renderHTML / 音视频 node view 拼上前缀。

import type { Editor, EditorOptions, JSONContent } from '@tiptap/core'
import { history } from '@tiptap/pm/history'
import { NodeSelection } from '@tiptap/pm/state'
import StarterKit from '@tiptap/starter-kit'
import { Placeholder, CharacterCount } from '@tiptap/extensions'
import { Markdown } from 'tiptap-markdown'
import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight'
import { TableKit } from '@tiptap/extension-table'
import { TaskList } from '@tiptap/extension-task-list'
import { TaskItem } from '@tiptap/extension-task-item'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import { common, createLowlight } from 'lowlight'
import CodeBlockNodeView from '../components/nodes/CodeBlockNodeView.vue'
import { DiaryLink, resolveLinkCandidates as applyLinkCandidates } from './diary-link'
import { SearchExtension } from './search'

import { post } from '../bridge/post'
import { setEditableState } from './editable'
import { MediaImage } from './image-node'
import { stripMediaPrefix } from './media'
import { Audio, Video } from './media-nodes'

const lowlight = createLowlight(common)

// 与 StarterKit 里 UndoRedo 扩展的默认值保持一致 —— 清空 undo 栈是把同一个 history 插件
// 换成新的，参数不同就等于顺手改了撤销行为。
const HISTORY_OPTIONS = { depth: 100, newGroupDelay: 500 }

export interface EditorApi {
  /** 灌入内容：TipTap 文档 JSON 串（新）或 markdown 文本（旧日记只读查看，自动识别）。 */
  setContent(content: string): void
  /** 取当前内容为 TipTap 文档 JSON 串（落库形态）。 */
  getContent(): string
  setEditable(value: boolean): void
  focus(): void
  blur(): void
  reset(): void
  insertMedia(name: string, alt?: string): void
  insertAudio(name: string): void
  insertVideo(name: string): void
  resolveUpload(id: string, name: string): void
  /** Flutter 回传 `[[` 双链候选（reqId 对应一次 requestLinkCandidates 请求；json 为 [{id,label}] 串）。 */
  resolveLinkCandidates(reqId: string, json: string): void
  /** 滚动到第 index 个 heading（文档序，与 Dart TiptapContent.headings 一致）；供目录跳转。不聚焦（不弹键盘）。 */
  scrollToHeading(index: number): void
  /**
   * Flutter 侧全屏播完退出后，把最终位置回灌给正文里那个 <video>，接着看不用从头找。
   * name 为裸文件名（与节点 attrs.filename 一致）。
   */
  resumeVideo(name: string, seconds: number): void
}

export interface EditorKitOptions {
  editable: boolean
  placeholder: string
  /** 内容变化回调，载荷为 TipTap 文档 JSON 串。 */
  onChange: (content: string) => void
  /** 可编辑性变化（Flutter 经 bridge.setEditable 切阅读↔编辑）回调；供组件驱动工具栏显隐。 */
  onEditableChange?: (value: boolean) => void
}

export interface EditorKit {
  options: Partial<EditorOptions>
  api: EditorApi
  attach(editor: Editor): void
}

/** 识别内容是否为 TipTap 文档 JSON（区别于旧 markdown 文本）。 */
function parseDoc(content: string): JSONContent | null {
  const trimmed = content.trimStart()
  if (!trimmed.startsWith('{')) return null
  try {
    const obj = JSON.parse(content)
    return obj && typeof obj === 'object' && obj.type === 'doc' ? (obj as JSONContent) : null
  } catch {
    return null
  }
}

export function createEditorKit(opts: EditorKitOptions): EditorKit {
  const { editable, placeholder, onChange, onEditableChange } = opts

  // onCreate 后由组件 attach 注入；此前各 api 方法 no-op（Flutter 仅在 ready 后调用，ready 即 onCreate）。
  let editor: Editor | null = null
  // 程序化写入（setContent/reset/转换）期间抑制 update 上报，避免把自己写的内容当成用户编辑回弹。
  let suppress = false
  // 拖拽/粘贴上传的暂存：id → 拿到存盘文件名后的插入回调。
  const pendingUploads = new Map<string, (name: string) => void>()
  let uploadSeq = 0

  // 块级媒体统一入口。atom 节点插入后选区落成该节点的 NodeSelection，直接再 insertContent
  // 会把它替换掉（多选图片连插只剩最后一张），故 NodeSelection 时改在节点之后插入。
  const insertBlock = (content: JSONContent): void => {
    const ed = editor
    if (!ed) return
    const { selection } = ed.state
    const chain = ed.chain().focus()
    if (selection instanceof NodeSelection) {
      chain.insertContentAt(selection.to, content)
    } else {
      chain.insertContent(content)
    }
    chain.run()
  }

  const insertImage = (name: string, alt?: string): void => {
    insertBlock({ type: 'image', attrs: { src: name, alt } })
  }

  const handleFiles = (files: FileList | null | undefined): boolean => {
    const images = files ? Array.from(files).filter((f) => f.type.startsWith('image/')) : []
    if (images.length === 0) return false
    for (const file of images) {
      const reader = new FileReader()
      reader.onload = () => {
        const dataUri = String(reader.result)
        const id = `up-${++uploadSeq}`
        pendingUploads.set(id, (name) => {
          if (name) insertImage(name)
        })
        post('saveImage', { id, dataUri, name: file.name })
      }
      reader.readAsDataURL(file)
    }
    return true
  }

  const withoutEmit = (fn: () => void): void => {
    suppress = true
    fn()
    suppress = false
  }

  // 灌入内容：JSON 文档直接 setContent(对象)；否则当 markdown 文本（旧日记），剥媒体前缀后
  // 交 tiptap-markdown 解析（setContent 收到字符串即按 markdown 解析）。
  const loadContent = (content: string): void => {
    const ed = editor
    if (!ed) return
    const doc = parseDoc(content)
    withoutEmit(() => {
      if (doc) {
        ed.commands.setContent(doc, { emitUpdate: false })
      } else {
        ed.commands.setContent(stripMediaPrefix(content), { emitUpdate: false })
      }
      // 重建 history 插件清空 undo 栈：灌入即新文档的起点，undo 不能穿越回上一篇
      //（页内双链跳转换日记）或空文档（首次打开）。
      //
      // 不能用 view.updateState(EditorState.create(...))：那条路绕过 dispatchTransaction，
      // @tiptap/vue-3 的 Editor 子类的响应式 state 不跟着走，而 updateStateInner 内部会拿陈旧
      // state 再 dispatch 一次，把刚清掉的 history 原样烤回来 —— 实测「灌入内容后按一次撤销，
      // 整篇变空」。register/unregisterPlugin 是公开路径，子类覆写里会同步响应式 state。
      ed.unregisterPlugin('history')
      ed.registerPlugin(history(HISTORY_OPTIONS))
    })
  }

  const options: Partial<EditorOptions> = {
    editable,
    content: '',
    extensions: [
      // 关掉 StarterKit 自带 codeBlock，换成带 lowlight 语法高亮的同名节点（二选一，否则重名冲突）。
      StarterKit.configure({ codeBlock: false }),
      // 自定义 node view 加「语言选择 + 复制按钮」头部；高亮仍由 CodeBlockLowlight 的 PM 插件按
      // node.attrs.language 着色（node view 与高亮插件并存，不冲突）。
      CodeBlockLowlight.configure({ lowlight }).extend({
        addNodeView() {
          return VueNodeViewRenderer(CodeBlockNodeView)
        },
      }),
      MediaImage,
      Audio,
      Video,
      // 表格（Table/Row/Header/Cell 一套，列宽可拖）。节点名为默认的 table/tableRow/tableHeader/
      // tableCell，正好匹配 tiptap-markdown 的表格序列化（GFM 简单表 ↔ 节点，复杂表降级 HTML）。
      TableKit.configure({ table: { resizable: true } }),
      // 任务列表（复选框）。节点名 taskList/taskItem，匹配 tiptap-markdown（markdown-it-task-lists）
      // 的 `- [ ]` 互转；nested 允许任务项内嵌套子任务。
      TaskList,
      TaskItem.configure({ nested: true }),
      // 双链正向链接：`[[` 触发，插入指向目标日记 uuid 的 diaryLink 节点（见 ./diary-link）。
      DiaryLink,
      // 字数统计：仅记录，editor.storage.characterCount.characters()/.words() 由组件读取展示。
      CharacterCount,
      // 编辑器内查找/替换（prosemirror-search 插件 + EditorSearchBar UI，见 ./search）。
      SearchExtension,
      Placeholder.configure({ placeholder }),
      // 仅用于「打开旧 markdown 日记（只读查看）」；落库用 JSON，不靠它序列化存储。
      Markdown.configure({ html: false, linkify: false, breaks: false, transformPastedText: true }),
    ],
    editorProps: {
      handlePaste: (_view, event) => handleFiles(event.clipboardData?.files),
      handleDrop: (_view, event) => handleFiles(event.dataTransfer?.files),
    },
    onUpdate: ({ editor }) => {
      if (!suppress) onChange(JSON.stringify(editor.getJSON()))
    },
    // 正文焦点变化上报（'editor' / ''），Flutter 据此做路由级焦点保存/恢复。
    onFocus: () => post('focusChange', 'editor'),
    onBlur: () => post('focusChange', ''),
  }

  const api: EditorApi = {
    setContent: (content) => loadContent(content ?? ''),
    getContent: () => (editor ? JSON.stringify(editor.getJSON()) : ''),
    setEditable: (value) => {
      editor?.setEditable(value, false)
      // setEditable(emitUpdate=false) 不触发 onUpdate，故 Vue 侧无从感知；显式回调驱动工具栏显隐，
      // 共享状态驱动 node view 内的编辑控件显隐。
      setEditableState(value)
      onEditableChange?.(value)
    },
    focus: () => {
      editor?.commands.focus()
    },
    blur: () => {
      editor?.commands.blur()
    },
    reset: () => {
      const ed = editor
      if (!ed) return
      withoutEmit(() => ed.commands.setContent('', { emitUpdate: false }))
    },
    insertMedia: (name, alt) => insertImage(name, alt),
    insertAudio: (name) => insertBlock({ type: 'audio', attrs: { filename: name } }),
    insertVideo: (name) => insertBlock({ type: 'video', attrs: { filename: name } }),
    resolveUpload: (id, name) => {
      const resolver = pendingUploads.get(id)
      if (resolver) {
        pendingUploads.delete(id)
        resolver(name)
      }
    },
    resolveLinkCandidates: (reqId, json) => applyLinkCandidates(reqId, json),
    resumeVideo: (name, seconds) => {
      const ed = editor
      if (!ed || !name) return
      const els = Array.from(
        ed.view.dom.querySelectorAll<HTMLVideoElement>('video.moodiary-video__el'),
      )
      const el = els.find((v) => v.src.endsWith(name))
      if (!el) return
      const apply = (): void => {
        try {
          el.currentTime = seconds
        } catch {
          // 个别 WebView 在 metadata 未就绪时设 currentTime 会抛。
        }
      }
      // readyState 0（HAVE_NOTHING）时设 currentTime 必抛，等 metadata 到了再设。
      if (el.readyState >= 1) apply()
      else el.addEventListener('loadedmetadata', apply, { once: true })
    },
    scrollToHeading: (index) => {
      const ed = editor
      if (!ed) return
      const positions: number[] = []
      ed.state.doc.descendants((node, pos) => {
        if (node.type.name === 'heading') positions.push(pos)
        return true
      })
      const pos = positions[index]
      if (pos == null) return
      const dom = ed.view.nodeDOM(pos) as HTMLElement | null
      dom?.scrollIntoView?.({ behavior: 'smooth', block: 'start' })
    },
  }

  return {
    options,
    api,
    attach: (e) => {
      editor = e
      // node view（图片尺寸角标等）读这个共享状态决定是否渲染编辑控件；初始值必须显式推入，
      // 否则只读浏览态会被当成可编辑。放在 attach 而非 createEditorKit 里：状态是模块级的，
      // 建了却没接上编辑器的 kit 不该影响已经在跑的那个。
      setEditableState(editable)
    },
  }
}
