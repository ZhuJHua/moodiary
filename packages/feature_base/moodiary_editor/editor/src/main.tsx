import { createRoot } from 'react-dom/client'
import { installBridge } from '@/core/bridge'
import type { EditorBoot } from '@/core/bridge/boot'
import { bootstrap } from '@/core/bridge/bootstrap'
import { request } from '@/core/bridge/request'
import EditorShell from '@/shell/EditorShell'
import './styles/moodiary-editor.css'

// file:// 页面带不了参数：先装桥向 Flutter 要 boot，拿到再渲染；WebView 透明，等待时什么都不画
installBridge()
void request<EditorBoot>('boot').then((boot) => {
  bootstrap(boot)
  createRoot(document.getElementById('app')!).render(<EditorShell />)
})
