<script setup lang="ts">
// 编辑器开发台（仅 dev）：在「手机 / 桌面」设备框里内嵌真实编辑器（iframe 加载 /），并模拟 Flutter
// 宿主 —— 用控件实时驱动 window.MoodiaryBridge（改配色 / 明暗 / 变体 / 对比度 / 可编辑 / 内容），
// 同时 mock window.MoodiaryEditor 接收编辑器回传的事件（change / saveImage / imageTap）。
// 编辑器源码（src/）改动经 Vite HMR 即时反映到 iframe 里,无需重跑 Flutter。样式用 Tailwind v4 +
// daisyUI（见 ./harness.css,仅本页加载,不进生产编辑器）。
import { onMounted, ref, watch } from 'vue'

type Device = 'phone' | 'desktop'
type Variant = 'tonalSpot' | 'monochrome'
interface SeedTheme {
  seed: string
  dark: boolean
  variant: Variant
  contrast: number
}

const SAMPLES: Record<string, string> = {
  基础排版: [
    '# 一级标题',
    '## 二级标题',
    '',
    '正文：**加粗**、*斜体*、~~删除线~~、`行内代码` 和 [链接](https://example.com)。',
    '',
    '> 引用块：今天天气不错。',
    '',
    '- 无序项 A',
    '- 无序项 B',
    '  - 嵌套项',
    '',
    '1. 有序一',
    '2. 有序二',
    '',
    '---',
    '',
    '结尾段落。',
  ].join('\n'),
  代码高亮: [
    '# 代码高亮',
    '',
    '```js',
    'function greet(name) {',
    '  const msg = `hello, ${name}` // 注释',
    '  console.log(msg)',
    '  return 42',
    '}',
    '```',
    '',
    '```python',
    'def add(a, b):',
    '    return a + b  # 注释',
    '```',
  ].join('\n'),
  '图片（外链）': [
    '# 图片',
    '',
    '![](https://picsum.photos/640/320)',
    '',
    '本地图片需在 Flutter 内运行才有媒体服务；dev 下用外链演示。',
  ].join('\n'),
  '空（看 placeholder）': '',
}

const device = ref<Device>('phone')
const dark = ref(false)
const seed = ref('#805610')
const variant = ref<Variant>('tonalSpot')
const contrast = ref(0)
const editable = ref(true)
const placeholder = ref('记录此刻…')
const sampleKey = ref('基础排版')
const inputMd = ref(SAMPLES['基础排版'])
const outputMd = ref('')

// 调试台外观主题（daisyUI 内置主题,按明暗分组；仅 harness 外壳,与编辑器预览主题无关）。localStorage 记忆。
const THEME_GROUPS: { label: string; themes: string[] }[] = [
  {
    label: '深色',
    themes: [
      'dim', 'dark', 'business', 'night', 'dracula', 'sunset', 'coffee',
      'forest', 'synthwave', 'halloween', 'aqua', 'black', 'luxury', 'abyss',
    ],
  },
  {
    label: '浅色',
    themes: [
      'light', 'cupcake', 'corporate', 'winter', 'nord', 'emerald', 'lofi',
      'pastel', 'bumblebee', 'retro', 'cyberpunk', 'valentine', 'garden',
      'fantasy', 'wireframe', 'cmyk', 'autumn', 'acid', 'lemonade', 'caramellatte', 'silk',
    ],
  },
]
const allThemes = THEME_GROUPS.flatMap((g) => g.themes)
const savedTheme = localStorage.getItem('harness-theme')
const harnessTheme = ref(savedTheme && allThemes.includes(savedTheme) ? savedTheme : 'dim')
// 主题菜单受控开关：点选项不关，便于连续切换；点外部才关。
const themeMenuOpen = ref(false)

const iframe = ref<HTMLIFrameElement>()
// pickImage 演示用外链占位的递增序号（避免重复 URL 被缓存成同一张）。
let imgSeq = 0
const iframeSrc = ref('')
// 顶部安全区的底色 = 编辑器实际背景色（--app-background）。同源 iframe,直接读编辑器算好的值,
// 与正文无缝（无需在 harness 里重算 material 配色）。默认用编辑器浅色兜底值。
const screenBg = ref('#fffdfb')

const theme = (): SeedTheme => ({
  seed: seed.value,
  dark: dark.value,
  variant: variant.value,
  contrast: contrast.value,
})

// boot 编码：与 editor 的 readBoot 一致 —— base64url(UTF-8 JSON)。
function bootParam(): string {
  const boot = {
    platform: device.value === 'phone' ? 'mobile' : 'desktop',
    editable: editable.value,
    placeholder: placeholder.value,
    theme: theme(),
  }
  const bytes = new TextEncoder().encode(JSON.stringify(boot))
  let bin = ''
  bytes.forEach((b) => (bin += String.fromCharCode(b)))
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

const bridge = () => (iframe.value?.contentWindow as any)?.MoodiaryBridge

function reloadIframe(): void {
  iframeSrc.value = `/?boot=${bootParam()}`
}

// 编辑器就绪后把当前控件状态推进去（首帧主题已走 boot；这里对齐最新值并灌内容）。
function pushAll(): void {
  const b = bridge()
  if (!b) return
  b.setTheme(theme())
  b.setEditable(editable.value)
  b.setContent(inputMd.value)
  syncScreenBg()
}

// 读 iframe 里编辑器算好的 --app-background,给安全区上色（setTheme 同步改内联样式,读即最新）。
function syncScreenBg(): void {
  const w = iframe.value?.contentWindow
  if (!w) return
  try {
    const bg = w.getComputedStyle(w.document.documentElement).getPropertyValue('--app-background').trim()
    if (bg) screenBg.value = bg
  } catch {
    /* cross-realm / 未就绪,忽略 */
  }
}

function onIframeLoad(): void {
  const w = iframe.value?.contentWindow as any
  if (!w) return
  // mock Flutter 的 JS→宿主通道,接收编辑器事件。
  w.MoodiaryEditor = {
    postMessage: (msg: string) => {
      let data: any
      try {
        data = JSON.parse(msg)
      } catch {
        return
      }
      const { type, payload } = data
      if (type === 'change') outputMd.value = typeof payload === 'string' ? payload : ''
      else if (type === 'ready') pushAll()
      else if (type === 'imageTap') console.log('[editor] imageTap', payload)
      else if (type === 'error') console.warn('[editor] error', payload)
      else if (type === 'pickImage') {
        // 真机里 Flutter 弹原生选图→存盘→insertMedia(裸文件名)；dev 无媒体服务,改插外链占位演示。
        bridge()?.insertMedia(`https://picsum.photos/480/280?random=${++imgSeq}`)
      } else if (type === 'pickAudio') {
        // dev 无媒体服务：音频卡片仅展示外观（不取流），插个占位文件名即可看节点样式。
        bridge()?.insertAudio('audio-demo.m4a')
      } else if (type === 'pickVideo') {
        // dev 无媒体服务,原生 <video> 取不到流（控件可见但不可播）；真机内联播放。
        bridge()?.insertVideo('video-demo.mp4')
      } else if (type === 'saveImage' && payload) {
        // dev 无媒体服务：直接用 dataUri 兑现,让拖拽/粘贴的图片就地显示。
        bridge()?.resolveImage(payload.id, payload.dataUri)
      } else if (type === 'requestLinkCandidates' && payload) {
        // dev mock：真机里 Flutter 用搜索引擎按相关性返回；这里按 query 过滤几条假数据,预览 [[ 搜索弹层。
        const pool = [
          { id: 'demo-1', label: '2026-06-01 · 去馆山旅行' },
          { id: 'demo-2', label: '读书笔记：克服焦虑' },
          { id: 'demo-3', label: '2026-05-20 · 晨跑' },
        ]
        const q = String(payload.query || '').trim().toLowerCase()
        // 空查询不列任何日记（与真机一致）；输入关键词后过滤。
        const list = q ? pool.filter((c) => c.label.toLowerCase().includes(q)) : []
        bridge()?.resolveLinkCandidates(payload.reqId, JSON.stringify(list))
      } else if (type === 'linkTap') {
        console.log('[editor] linkTap', payload)
      }
    },
  }
  pushAll()
}

// 实时控件（无需重载）：主题 / 可编辑 / 内容直接走 bridge。
watch([dark, seed, variant, contrast], () => {
  bridge()?.setTheme(theme())
  syncScreenBg()
})
watch(editable, (v) => bridge()?.setEditable(v))
watch(sampleKey, (k) => (inputMd.value = SAMPLES[k] ?? ''))

let mdTimer: number | undefined
watch(inputMd, (v) => {
  clearTimeout(mdTimer)
  mdTimer = window.setTimeout(() => bridge()?.setContent(v), 250)
})

// placeholder 在创建时定（无运行时 setter）→ 改它重载 iframe 带新 boot。
watch(placeholder, () => reloadIframe())
// platform 也在 boot 里定（决定工具栏置顶/置底）→ 切设备需重载 iframe 才能换工具栏位置。
watch(device, () => reloadIframe())

// 记忆调试台主题选择。
watch(harnessTheme, (v) => localStorage.setItem('harness-theme', v))

onMounted(() => reloadIframe())
</script>

<template>
  <div class="flex h-screen bg-base-100 text-base-content" :data-theme="harnessTheme">
    <!-- 控制面板 -->
    <aside class="w-80 shrink-0 overflow-y-auto border-r border-base-300 bg-base-200">
      <div class="space-y-4 p-4">
        <div class="flex items-center justify-between gap-2">
          <h1 class="text-sm font-semibold">Moodiary Editor</h1>
          <!-- 调试台外观主题切换（仅 harness,不影响编辑器预览）；点选项后菜单保持打开,便于连试 -->
          <div class="dropdown dropdown-end" :class="{ 'dropdown-open': themeMenuOpen }">
            <button type="button" class="btn btn-xs btn-ghost gap-1.5" title="调试台外观主题" @click="themeMenuOpen = !themeMenuOpen">
              <span :data-theme="harnessTheme" class="inline-flex rounded bg-base-100 p-0.5">
                <span class="size-2 rounded-full bg-primary"></span>
              </span>
              {{ harnessTheme }}
              <span class="text-[10px] opacity-60">▾</span>
            </button>
            <ul class="dropdown-content menu z-50 mt-1 max-h-[60vh] w-48 overflow-y-auto rounded-box border border-base-300 bg-base-100 p-2 shadow-lg">
              <template v-for="g in THEME_GROUPS" :key="g.label">
                <li class="menu-title">{{ g.label }}</li>
                <li v-for="t in g.themes" :key="t">
                  <button
                    type="button" class="flex items-center gap-2"
                    :class="t === harnessTheme ? 'bg-primary text-primary-content' : ''"
                    @click="harnessTheme = t"
                  >
                    <span :data-theme="t" class="inline-flex rounded bg-base-100 p-0.5">
                      <span class="size-2.5 rounded-full bg-primary"></span>
                    </span>
                    {{ t }}
                  </button>
                </li>
              </template>
            </ul>
          </div>
        </div>

        <!-- 设备 -->
        <div class="flex items-center justify-between gap-3">
          <span class="text-sm">设备</span>
          <div class="join">
            <button class="btn btn-sm join-item" :class="device === 'phone' ? 'btn-primary' : 'btn-ghost'" @click="device = 'phone'">手机</button>
            <button class="btn btn-sm join-item" :class="device === 'desktop' ? 'btn-primary' : 'btn-ghost'" @click="device = 'desktop'">桌面</button>
          </div>
        </div>

        <div class="divider my-1 text-xs opacity-60">主题</div>

        <!-- 明暗 -->
        <div class="flex items-center justify-between gap-3">
          <span class="text-sm">明暗</span>
          <div class="join">
            <button class="btn btn-sm join-item" :class="!dark ? 'btn-primary' : 'btn-ghost'" @click="dark = false">浅色</button>
            <button class="btn btn-sm join-item" :class="dark ? 'btn-primary' : 'btn-ghost'" @click="dark = true">深色</button>
          </div>
        </div>

        <!-- 种子色 -->
        <div class="flex items-center justify-between gap-3">
          <span class="text-sm">种子色</span>
          <div class="flex items-center gap-2">
            <input type="color" v-model="seed" class="h-8 w-10 cursor-pointer rounded border border-base-300 bg-base-100" />
            <code class="text-xs opacity-60">{{ seed }}</code>
          </div>
        </div>

        <!-- 变体 -->
        <div class="flex items-center justify-between gap-3">
          <span class="text-sm">变体</span>
          <div class="join">
            <button class="btn btn-sm join-item" :class="variant === 'tonalSpot' ? 'btn-primary' : 'btn-ghost'" @click="variant = 'tonalSpot'">tonalSpot</button>
            <button class="btn btn-sm join-item" :class="variant === 'monochrome' ? 'btn-primary' : 'btn-ghost'" @click="variant = 'monochrome'">mono</button>
          </div>
        </div>

        <!-- 对比度 -->
        <div>
          <div class="mb-1 flex items-center justify-between">
            <span class="text-sm">对比度</span>
            <span class="font-mono text-xs opacity-60">{{ contrast.toFixed(1) }}</span>
          </div>
          <input type="range" min="-1" max="1" step="0.1" v-model.number="contrast" class="range range-primary range-xs" />
        </div>

        <div class="divider my-1 text-xs opacity-60">行为</div>

        <!-- 可编辑 -->
        <div class="flex items-center justify-between gap-3">
          <span class="text-sm">可编辑</span>
          <input type="checkbox" v-model="editable" class="toggle toggle-primary toggle-sm" />
        </div>

        <!-- 占位符 -->
        <label class="block">
          <span class="mb-1 block text-sm">占位符 <span class="text-xs opacity-60">(改动重载)</span></span>
          <input type="text" v-model="placeholder" class="input input-sm w-full" />
        </label>

        <div class="divider my-1 text-xs opacity-60">内容</div>

        <!-- 示例 -->
        <label class="block">
          <span class="mb-1 block text-sm">示例</span>
          <select v-model="sampleKey" class="select select-sm w-full">
            <option v-for="k in Object.keys(SAMPLES)" :key="k" :value="k">{{ k }}</option>
          </select>
        </label>

        <!-- 推送 markdown -->
        <label class="block">
          <span class="mb-1 block text-sm">推送 Markdown</span>
          <textarea v-model="inputMd" rows="8" spellcheck="false" class="textarea textarea-sm w-full font-mono leading-relaxed"></textarea>
        </label>

        <!-- 输出 -->
        <label class="block">
          <span class="mb-1 block text-sm">编辑器输出 <span class="text-xs opacity-60">(change 回传)</span></span>
          <textarea :value="outputMd" rows="6" readonly spellcheck="false" class="textarea textarea-sm w-full font-mono leading-relaxed opacity-70"></textarea>
        </label>
      </div>
    </aside>

    <!-- 预览舞台 -->
    <main class="grid flex-1 place-items-center overflow-auto bg-base-300 p-6">
      <!-- 手机：display 用 flex-col + 顶部安全区（pt-12），让正文从刘海/状态栏下方开始
           （模拟 Flutter 把 webview 放在状态栏下方的布局，编辑器本身不带 safe-area padding）。 -->
      <!-- 按视口高度定尺寸（保持 462:978 比例,w≈h*0.472）,这样总能完整显示并与窗口边缘留白,
           不再被裁切/贴边（覆盖 daisyUI 的 width:100% + aspect-ratio）。 -->
      <div v-if="device === 'phone'" class="mockup-phone border-base-content/15 h-[80vh] w-[37.8vh]">
        <div class="mockup-phone-camera"></div>
        <div class="mockup-phone-display flex flex-col pt-12" :style="{ backgroundColor: screenBg }">
          <iframe ref="iframe" :src="iframeSrc" title="editor preview" @load="onIframeLoad" class="min-h-0 w-full flex-1 border-0 bg-transparent" />
        </div>
      </div>
      <!-- 桌面 -->
      <div v-else class="mockup-window w-[min(1100px,92%)] border border-base-300 bg-base-200">
        <iframe ref="iframe" :src="iframeSrc" title="editor preview" @load="onIframeLoad" class="h-[min(680px,78vh)] w-full border-0 bg-base-100" />
      </div>
    </main>

    <!-- 点击菜单外部关闭主题菜单（菜单内容 z-50 在此层之上,点选项不会命中此层）。 -->
    <div v-if="themeMenuOpen" class="fixed inset-0 z-40" @click="themeMenuOpen = false" />
  </div>
</template>
