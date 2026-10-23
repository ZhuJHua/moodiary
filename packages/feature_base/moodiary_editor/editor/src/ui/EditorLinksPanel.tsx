import { ArrowUpRight, ChevronRight, CornerDownLeft, Link, Waypoints } from 'lucide-react'
import { post } from '@/core/bridge/post'
import type { EditorLinks } from '@/core/state/meta'

export default function EditorLinksPanel({ links }: { links: EditorLinks }) {
  const sections = [
    { label: links.outgoingLabel, items: links.outgoing, outgoing: true },
    { label: links.incomingLabel, items: links.incoming, outgoing: false },
  ]

  return (
    <section className="md-links">
      <div className="md-links__head">
        <Link className="md-links__icon" />
        <span className="md-links__title">{links.title}</span>
        <span className="md-links__count">{links.outgoing.length + links.incoming.length}</span>
        <span className="md-links__spacer" />
        <button
          type="button"
          className="md-icon-button"
          aria-label={links.graphTip}
          title={links.graphTip}
          onClick={() => post('openGraph')}
        >
          <Waypoints />
        </button>
      </div>
      {sections.map((section) =>
        section.items.length ? (
          <div key={section.label}>
            <div className="md-links__section">{section.label}</div>
            <ul className="md-links__list">
              {section.items.map((item) => (
                <li key={item.id}>
                  <button type="button" className="md-links__item" onClick={() => post('linkTap', { id: item.id })}>
                    <span className="md-links__badge">
                      {section.outgoing ? <ArrowUpRight /> : <CornerDownLeft />}
                    </span>
                    <span className="md-links__text">
                      <span className="md-links__item-title">{item.title}</span>
                      {item.subtitle && <span className="md-links__item-sub">{item.subtitle}</span>}
                    </span>
                    <ChevronRight className="md-links__chevron" />
                  </button>
                </li>
              ))}
            </ul>
          </div>
        ) : null,
      )}
    </section>
  )
}
