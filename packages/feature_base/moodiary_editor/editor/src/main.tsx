import { createRoot } from 'react-dom/client'
import { bootstrap } from '@/core/bridge/bootstrap'
import EditorShell from '@/shell/EditorShell'
import './styles/moodiary-editor.css'

const { platform } = bootstrap()
createRoot(document.getElementById('app')!).render(<EditorShell platform={platform} />)
