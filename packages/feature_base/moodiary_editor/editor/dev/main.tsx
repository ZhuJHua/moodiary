import { createRoot } from 'react-dom/client'
import './harness.css'
import Harness from './Harness'

createRoot(document.getElementById('harness')!).render(<Harness />)
