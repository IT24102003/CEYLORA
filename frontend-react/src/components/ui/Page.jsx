import { useState } from "react";
import { SlidersHorizontal } from "lucide-react";
import { Button, Card } from "./Primitives";
import { Modal } from "./Overlay";

export function PageHeader({ title, subtitle, actions }) {
  return (
    <header className="page-header">
      <div>
        <h1 className="page-header__title">{title}</h1>
        {subtitle && <p className="page-header__sub">{subtitle}</p>}
      </div>
      {actions && <div className="page-header__actions">{actions}</div>}
    </header>
  );
}

/**
 * Search row + filters. On desktop the filters sit inline; on mobile they collapse
 * into a "Filters" button that opens a bottom sheet.
 */
export function Toolbar({ search, filters, activeFilters = 0, onApply, onReset, children }) {
  const [sheet, setSheet] = useState(false);
  return (
    <>
      <div className="toolbar">
        {search}
        {filters && <div className="toolbar__filters">{filters}</div>}
        {filters && (
          <Button className="filter-toggle" icon={SlidersHorizontal} onClick={() => setSheet(true)}>
            Filters {activeFilters > 0 && <span className="filter-count">{activeFilters}</span>}
          </Button>
        )}
        {onApply && <Button variant="primary" onClick={onApply}>Search</Button>}
        {children}
      </div>
      {sheet && (
        <Modal
          title="Filters"
          onClose={() => setSheet(false)}
          footer={
            <>
              {onReset && <Button onClick={() => { onReset(); setSheet(false); }}>Reset</Button>}
              <Button variant="primary" onClick={() => { onApply?.(); setSheet(false); }}>Show results</Button>
            </>
          }
        >
          <div className="stack">{filters}</div>
        </Modal>
      )}
    </>
  );
}

export function StatCard({ label, value, note, icon: Icon, tone }) {
  return (
    <Card className="stat">
      <div className="stat__top">
        <span>{label}</span>
        {Icon && <span className={`stat__icon${tone ? ` stat__icon--${tone}` : ""}`}><Icon size={17} aria-hidden="true" /></span>}
      </div>
      <div className="stat__value">{value}</div>
      {note && <div className="stat__note">{note}</div>}
    </Card>
  );
}
