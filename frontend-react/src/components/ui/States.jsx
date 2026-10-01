import { AlertTriangle, Inbox } from "lucide-react";
import { Button, Skeleton } from "./Primitives";

export function EmptyState({ icon: Icon = Inbox, title, text, action }) {
  return (
    <div className="state">
      <div className="state__icon"><Icon size={26} aria-hidden="true" /></div>
      <h3 className="state__title">{title}</h3>
      {text && <p className="state__text">{text}</p>}
      {action && <div className="state__actions">{action}</div>}
    </div>
  );
}

export function ErrorState({ title = "Something went wrong", text, onRetry }) {
  return (
    <div className="state state--error" role="alert">
      <div className="state__icon"><AlertTriangle size={26} aria-hidden="true" /></div>
      <h3 className="state__title">{title}</h3>
      {text && <p className="state__text">{text}</p>}
      {onRetry && <div className="state__actions"><Button onClick={onRetry}>Try again</Button></div>}
    </div>
  );
}

export function TableSkeleton({ rows = 6 }) {
  return (
    <div style={{ padding: "var(--space-2) var(--space-4)" }} aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="row" style={{ padding: "12px 0", borderBottom: "1px solid var(--c-border)" }}>
          <Skeleton w={56} h={40} />
          <div style={{ flex: 1, display: "grid", gap: 8 }}>
            <Skeleton w={`${40 + ((i * 17) % 30)}%`} h={13} />
            <Skeleton w="22%" h={10} />
          </div>
          <Skeleton w={72} h={22} r={11} />
        </div>
      ))}
    </div>
  );
}

export function CardsSkeleton({ count = 3 }) {
  return (
    <div className="stack" aria-busy="true" aria-label="Loading">
      {Array.from({ length: count }, (_, i) => (
        <div key={i} className="card card--pad" style={{ display: "grid", gap: 10 }}>
          <Skeleton w="30%" h={16} />
          <Skeleton w="60%" h={12} />
          <Skeleton w="45%" h={12} />
        </div>
      ))}
    </div>
  );
}
