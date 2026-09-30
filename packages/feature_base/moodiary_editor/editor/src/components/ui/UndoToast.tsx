import { runUndoToast, undoToast } from '../../editor/undo-toast'
import { useT } from '../../i18n'
import { useStore } from '../../lib/store'

export default function UndoToast() {
  const t = useT()
  const { visible, message } = useStore(undoToast)
  return (
    <div className="relative">
      {visible && (
        <div
          className="absolute bottom-full left-1/2 z-[80] mb-3 -translate-x-1/2 whitespace-nowrap"
          role="status"
        >
          <div className="flex items-center gap-2 rounded-lg border border-border bg-popover py-2 pr-2 pl-4 text-sm text-popover-foreground shadow-lg">
            <span>{message}</span>
            <button
              type="button"
              className="rounded-md px-3 py-1.5 font-semibold text-primary active:bg-accent"
              onMouseDown={(e) => e.preventDefault()}
              onClick={runUndoToast}
            >
              {t('block.undo')}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
