import { Card } from "./Primitives";
import { assetUrl } from "../../services/api";

/**
 * columns: [{ key, header, render?(row), primary?, actions? }]
 * Renders as a table on desktop and as stacked cards (label/value rows) below 900px.
 */
export default function DataTable({ columns, rows, rowKey = "id", caption }) {
  return (
    <Card>
      <div className="table-wrap">
        <table className="dt">
          {caption && <caption className="sr-only">{caption}</caption>}
          <thead>
            <tr>
              {columns.map((c) => (
                <th key={c.key} scope="col">{c.actions ? <span className="sr-only">Actions</span> : c.header}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, i) => (
              <tr key={row[rowKey]} style={{ "--i": Math.min(i, 12) }}>
                {columns.map((c) => (
                  <td
                    key={c.key}
                    data-label={c.actions || c.primary ? undefined : c.header}
                    className={c.actions ? "cell-actions" : c.primary ? "cell-primary" : undefined}
                  >
                    {c.render ? c.render(row) : row[c.key] ?? "—"}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

export function Thumb({ src, alt = "", icon: Icon }) {
  return src ? (
    <img className="thumb" src={assetUrl(src)} alt={alt} loading="lazy" onError={(e) => { e.currentTarget.style.visibility = "hidden"; }} />
  ) : (
    <span className="thumb" aria-hidden="true">{Icon && <Icon size={18} />}</span>
  );
}
