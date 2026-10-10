import { ArrowUpRight, ChevronRight, CornerDownLeft, Link, Waypoints } from 'lucide-react'
import { cn } from 'cn'
import type { EditorLinkItem, EditorLinks } from '@/core/state/meta'
import { post } from '@/core/bridge/post'
import { Badge } from '@/ui/primitives/badge'
import { Button } from '@/ui/primitives/button'
import { keepFocus } from '@/lib/utils'

export default function EditorLinksPanel({ links }: { links: EditorLinks }) {
  const sections = [
    { label: links.outgoingLabel, items: links.outgoing, outgoing: true },
    { label: links.incomingLabel, items: links.incoming, outgoing: false },
  ]

  function onOpen(item: EditorLinkItem): void {
    post('linkTap', { id: item.id })
  }

  return (
    <div className="links-panel mx-4 my-6 flex-none rounded-lg bg-muted font-(family-name:--app-font-sans)">
      <div className="flex flex-col gap-1 p-3 pl-3.5">
        <div className="flex items-center gap-2">
          <Link className="size-4 text-muted-foreground" />
          <span className="text-sm font-semibold">{links.title}</span>
          <Badge variant="outline">{links.outgoing.length + links.incoming.length}</Badge>
          <span className="flex-1" />
          <Button
            variant="ghost"
            size="icon"
            title={links.graphTip}
            onMouseDown={keepFocus}
            onClick={() => post('openGraph')}
          >
            <Waypoints className="size-5" />
          </Button>
        </div>
        {sections.map((section) =>
          section.items.length ? (
            <div key={section.label} className="contents">
              <div className="mt-2 px-1 text-xs text-muted-foreground">{section.label}</div>
              <ul className="flex flex-col">
                {section.items.map((item) => (
                  <li key={item.id}>
                    <button
                      type="button"
                      className="flex w-full items-center gap-3 rounded-md px-1 py-2 text-left active:bg-accent"
                      onMouseDown={keepFocus}
                      onClick={() => onOpen(item)}
                    >
                      <span
                        className={cn(
                          'grid size-8 shrink-0 place-items-center rounded-full',
                          section.outgoing
                            ? 'bg-primary/15 text-primary'
                            : 'bg-accent text-accent-foreground',
                        )}
                      >
                        {section.outgoing ? (
                          <ArrowUpRight className="size-[18px]" />
                        ) : (
                          <CornerDownLeft className="size-[18px]" />
                        )}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-medium">{item.title}</span>
                        {item.subtitle && (
                          <span className="block truncate text-xs text-muted-foreground">
                            {item.subtitle}
                          </span>
                        )}
                      </span>
                      <ChevronRight className="size-4 shrink-0 opacity-40" />
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          ) : null,
        )}
      </div>
    </div>
  )
}
