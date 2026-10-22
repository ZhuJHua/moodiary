import { createRoot } from 'react-dom/client'
import { installBridge } from '@/core/bridge'
import { bootstrap, type EditorBoot } from '@/core/bridge/boot'
import { installChangeFlushers } from '@/core/bridge/change'
import { request } from '@/core/bridge/request'
import EditorShell from '@/ui/EditorShell'
import './styles/editor.scss'

installBridge()
installChangeFlushers()
void request<EditorBoot>('boot').then((boot) => {
  bootstrap(boot)
  createRoot(document.getElementById('app')!).render(<EditorShell />)
})
