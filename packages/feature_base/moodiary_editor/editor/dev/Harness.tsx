import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import {
  Hct,
  MaterialDynamicColors,
  SchemeMonochrome,
  SchemeTonalSpot,
  argbFromHex,
  hexFromArgb,
  type DynamicColor,
} from '@material/material-color-utilities'
import { Moon, Sun } from 'lucide-react'
import { Button } from '../src/components/ui/button'
import { Input } from '../src/components/ui/input'
import { Toggle } from '../src/components/ui/toggle'
import type { EditorRoles, EditorTheme } from '../src/bridge/theme'

type Device = 'phone' | 'desktop'
type Variant = 'tonalSpot' | 'monochrome'

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
  '空（看占位符）': '',
}

const LINK_POOL = [
  { id: 'demo-1', label: '2026-06-01 · 去馆山旅行' },
  { id: 'demo-2', label: '读书笔记：克服焦虑' },
  { id: 'demo-3', label: '2026-05-20 · 晨跑' },
]

const SELECT =
  'h-8 w-full rounded-lg border border-input bg-transparent px-2 text-sm outline-none focus-visible:border-ring'
const TEXTAREA =
  'w-full rounded-lg border border-input bg-transparent px-2.5 py-1.5 font-mono text-xs leading-relaxed outline-none focus-visible:border-ring'
const RANGE =
  'h-2 w-full cursor-pointer appearance-none rounded-full bg-muted outline-none [&::-webkit-slider-thumb]:size-4 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-primary [&::-moz-range-thumb]:size-4 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:border-0 [&::-moz-range-thumb]:bg-primary'

function buildTheme(seed: string, variant: Variant, dark: boolean, contrast: number): EditorTheme {
  const source = Hct.fromInt(argbFromHex(seed))
  const scheme =
    variant === 'monochrome'
      ? new SchemeMonochrome(source, dark, contrast)
      : new SchemeTonalSpot(source, dark, contrast)
  const of = (role: DynamicColor): string => hexFromArgb(role.getArgb(scheme))
  const roles: EditorRoles = {
    surface: of(MaterialDynamicColors.surface),
    onSurface: of(MaterialDynamicColors.onSurface),
    onSurfaceVariant: of(MaterialDynamicColors.onSurfaceVariant),
    surfaceContainerLow: of(MaterialDynamicColors.surfaceContainerLow),
    surfaceContainer: of(MaterialDynamicColors.surfaceContainer),
    surfaceContainerHigh: of(MaterialDynamicColors.surfaceContainerHigh),
    surfaceContainerHighest: of(MaterialDynamicColors.surfaceContainerHighest),
    primary: of(MaterialDynamicColors.primary),
    onPrimary: of(MaterialDynamicColors.onPrimary),
    secondaryContainer: of(MaterialDynamicColors.secondaryContainer),
    onSecondaryContainer: of(MaterialDynamicColors.onSecondaryContainer),
    inverseSurface: of(MaterialDynamicColors.inverseSurface),
    onInverseSurface: of(MaterialDynamicColors.inverseOnSurface),
    outlineVariant: of(MaterialDynamicColors.outlineVariant),
    error: of(MaterialDynamicColors.error),
  }
  return { roles, dark }
}

// boot 编码需与 editor 的 readBoot 一致：base64url(UTF-8 JSON)
function encodeBoot(boot: unknown): string {
  const bytes = new TextEncoder().encode(JSON.stringify(boot))
  let bin = ''
  bytes.forEach((b) => (bin += String.fromCharCode(b)))
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function stored(key: string): string | null {
  try {
    return localStorage.getItem(key)
  } catch {
    return null
  }
}
function remember(key: string, value: string): void {
  try {
    localStorage.setItem(key, value)
  } catch {
  }
}

function Row({ label, children }: { label: ReactNode; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-sm">{label}</span>
      {children}
    </div>
  )
}

function Segmented<T extends string>({
  value,
  options,
  onChange,
}: {
  value: T
  options: Array<[T, string]>
  onChange: (next: T) => void
}) {
  return (
    <div className="flex gap-1">
      {options.map(([key, label]) => (
        <Button
          key={key}
          size="sm"
          variant={value === key ? 'default' : 'ghost'}
          onClick={() => onChange(key)}
        >
          {label}
        </Button>
      ))}
    </div>
  )
}

function Divider({ children }: { children: ReactNode }) {
  return (
    <div className="flex items-center gap-2 text-xs text-muted-foreground">
      <div className="h-px flex-1 bg-border" />
      {children}
      <div className="h-px flex-1 bg-border" />
    </div>
  )
}

export default function Harness() {
  const [device, setDevice] = useState<Device>('phone')
  const [dark, setDark] = useState(false)
  const [seed, setSeed] = useState('#805610')
  const [variant, setVariant] = useState<Variant>('tonalSpot')
  const [contrast, setContrast] = useState(0)
  const [editable, setEditable] = useState(() => stored('harness-editable') !== 'false')
  const [locale, setLocale] = useState('zh')
  const [sampleKey, setSampleKey] = useState('基础排版')
  const [inputMd, setInputMd] = useState(SAMPLES['基础排版'])
  const [outputMd, setOutputMd] = useState('')
  const [harnessDark, setHarnessDark] = useState(() => stored('harness-theme') === 'dark')
  const [iframeSrc, setIframeSrc] = useState('')
  const [screenBg, setScreenBg] = useState('#fffdfb')

  const iframe = useRef<HTMLIFrameElement>(null)
  const imgSeq = useRef(0)
  const theme = useMemo(() => buildTheme(seed, variant, dark, contrast), [seed, variant, dark, contrast])
  // 事件回调里要读最新值，但不想让它们成为重载 iframe 的依赖
  const latest = useRef({ theme, editable, inputMd })
  latest.current = { theme, editable, inputMd }

  const bridge = () => iframe.current?.contentWindow?.MoodiaryBridge

  function syncScreenBg(): void {
    const w = iframe.current?.contentWindow
    if (!w) return
    try {
      const bg = w.getComputedStyle(w.document.documentElement).getPropertyValue('--app-background').trim()
      if (bg) setScreenBg(bg)
    } catch {
    }
  }

  function pushAll(): void {
    const b = bridge()
    if (!b) return
    b.setTheme(latest.current.theme)
    b.setEditable(latest.current.editable)
    b.setContent(latest.current.inputMd)
    syncScreenBg()
  }

  function onIframeLoad(): void {
    const w = iframe.current?.contentWindow
    if (!w) return
    w.MoodiaryEditor = {
      postMessage: (msg: string) => {
        let data: { type?: string; payload?: unknown }
        try {
          data = JSON.parse(msg)
        } catch {
          return
        }
        const { type, payload } = data
        if (type === 'change') setOutputMd(typeof payload === 'string' ? payload : '')
        else if (type === 'ready') pushAll()
        else if (type === 'imageTap') console.log('[editor] imageTap', payload)
        else if (type === 'error') console.warn('[editor] error', payload)
        else if (type === 'pickImage') {
          bridge()?.insertMedia(`https://picsum.photos/480/280?random=${++imgSeq.current}`)
        } else if (type === 'pickAudioFile' || type === 'recordAudio') {
          bridge()?.insertAudio('audio-demo.m4a')
        } else if (type === 'pickVideo') {
          bridge()?.insertVideo('video-demo.mp4')
        } else if (type === 'saveImage' && payload) {
          const { id, dataUri } = payload as { id: string; dataUri: string }
          bridge()?.resolveImage(id, dataUri)
        } else if (type === 'requestLinkCandidates' && payload) {
          const { reqId, query } = payload as { reqId: string; query?: string }
          const q = String(query ?? '').trim().toLowerCase()
          const list = q ? LINK_POOL.filter((c) => c.label.toLowerCase().includes(q)) : []
          bridge()?.resolveLinkCandidates(reqId, JSON.stringify(list))
        } else if (type === 'linkTap') {
          console.log('[editor] linkTap', payload)
        }
      },
    }
    pushAll()
  }

  useEffect(() => {
    bridge()?.setTheme(theme)
    syncScreenBg()
  }, [theme])

  useEffect(() => {
    remember('harness-editable', String(editable))
    bridge()?.setEditable(editable)
  }, [editable])

  useEffect(() => {
    const timer = window.setTimeout(() => bridge()?.setContent(inputMd), 250)
    return () => window.clearTimeout(timer)
  }, [inputMd])

  // platform 与 locale 只在 boot 里定，切换需重载 iframe
  useEffect(() => {
    const boot = {
      platform: device === 'phone' ? 'mobile' : 'desktop',
      editable: latest.current.editable,
      locale,
      theme: latest.current.theme,
    }
    setIframeSrc(`/?boot=${encodeBoot(boot)}`)
  }, [device, locale])

  useEffect(() => {
    remember('harness-theme', harnessDark ? 'dark' : 'light')
  }, [harnessDark])

  const frame = (
    <iframe
      ref={iframe}
      src={iframeSrc}
      title="editor preview"
      onLoad={onIframeLoad}
      className={
        device === 'phone'
          ? 'min-h-0 w-full flex-1 border-0 bg-transparent'
          : 'h-[min(680px,78vh)] w-full border-0 bg-background'
      }
    />
  )

  return (
    <div className={`flex h-screen bg-background text-foreground${harnessDark ? ' dark' : ''}`}>
      <aside className="w-80 shrink-0 overflow-y-auto border-r border-border bg-card">
        <div className="space-y-4 p-4">
          <div className="flex items-center justify-between gap-2">
            <h1 className="text-sm font-semibold">Moodiary Editor</h1>
            <Toggle
              size="sm"
              pressed={harnessDark}
              onPressedChange={setHarnessDark}
              aria-label="调试台明暗"
              title="调试台明暗"
            >
              {harnessDark ? <Moon className="size-4" /> : <Sun className="size-4" />}
            </Toggle>
          </div>

          <Row label="设备">
            <Segmented
              value={device}
              options={[
                ['phone', '手机'],
                ['desktop', '桌面'],
              ]}
              onChange={setDevice}
            />
          </Row>

          <Divider>主题</Divider>

          <Row label="明暗">
            <Segmented
              value={dark ? 'dark' : 'light'}
              options={[
                ['light', '浅色'],
                ['dark', '深色'],
              ]}
              onChange={(v) => setDark(v === 'dark')}
            />
          </Row>

          <Row label="种子色">
            <div className="flex items-center gap-2">
              <Input
                type="color"
                value={seed}
                onChange={(e) => setSeed(e.currentTarget.value)}
                className="h-8 w-10 cursor-pointer p-1"
              />
              <code className="text-xs text-muted-foreground">{seed}</code>
            </div>
          </Row>

          <Row label="变体">
            <Segmented
              value={variant}
              options={[
                ['tonalSpot', 'tonalSpot'],
                ['monochrome', 'mono'],
              ]}
              onChange={setVariant}
            />
          </Row>

          <div>
            <div className="mb-1 flex items-center justify-between">
              <span className="text-sm">对比度</span>
              <span className="font-mono text-xs text-muted-foreground">{contrast.toFixed(1)}</span>
            </div>
            <input
              type="range"
              min={-1}
              max={1}
              step={0.1}
              value={contrast}
              onChange={(e) => setContrast(Number(e.currentTarget.value))}
              className={RANGE}
            />
          </div>

          <Divider>行为</Divider>

          <Row label="可编辑">
            <Toggle size="sm" variant="outline" pressed={editable} onPressedChange={setEditable}>
              {editable ? '开' : '关'}
            </Toggle>
          </Row>

          <label className="block">
            <span className="mb-1 block text-sm">
              语言 <span className="text-xs text-muted-foreground">(改动重载)</span>
            </span>
            <select value={locale} onChange={(e) => setLocale(e.currentTarget.value)} className={SELECT}>
              <option value="zh">中文</option>
              <option value="en">English</option>
            </select>
          </label>

          <Divider>内容</Divider>

          <label className="block">
            <span className="mb-1 block text-sm">示例</span>
            <select
              value={sampleKey}
              onChange={(e) => {
                const k = e.currentTarget.value
                setSampleKey(k)
                setInputMd(SAMPLES[k] ?? '')
              }}
              className={SELECT}
            >
              {Object.keys(SAMPLES).map((k) => (
                <option key={k} value={k}>
                  {k}
                </option>
              ))}
            </select>
          </label>

          <label className="block">
            <span className="mb-1 block text-sm">推送 Markdown</span>
            <textarea
              value={inputMd}
              onChange={(e) => setInputMd(e.currentTarget.value)}
              rows={8}
              spellCheck={false}
              className={TEXTAREA}
            />
          </label>

          <label className="block">
            <span className="mb-1 block text-sm">
              编辑器输出 <span className="text-xs text-muted-foreground">(change 回传)</span>
            </span>
            <textarea
              value={outputMd}
              readOnly
              rows={6}
              spellCheck={false}
              className={`${TEXTAREA} text-muted-foreground`}
            />
          </label>
        </div>
      </aside>

      <main className="grid flex-1 place-items-center overflow-auto bg-muted p-6">
        {device === 'phone' ? (
          // 462:978 比例，w ≈ h*0.472
          <div className="relative h-[80vh] w-[37.8vh] rounded-[3rem] border-[10px] border-neutral-900 bg-neutral-900 shadow-2xl">
            <div className="absolute top-3 left-1/2 z-10 h-6 w-28 -translate-x-1/2 rounded-full bg-neutral-900" />
            <div
              className="flex h-full flex-col overflow-hidden rounded-[2.4rem] pt-12"
              style={{ backgroundColor: screenBg }}
            >
              {frame}
            </div>
          </div>
        ) : (
          <div className="w-[min(1100px,92%)] overflow-hidden rounded-xl border border-border bg-card shadow-lg">
            <div className="flex items-center gap-1.5 border-b border-border px-3 py-2">
              <span className="size-3 rounded-full bg-red-400" />
              <span className="size-3 rounded-full bg-yellow-400" />
              <span className="size-3 rounded-full bg-green-400" />
            </div>
            {frame}
          </div>
        )}
      </main>
    </div>
  )
}
