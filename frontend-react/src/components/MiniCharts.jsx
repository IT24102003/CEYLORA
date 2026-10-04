import { useId } from "react";

// Small dependency-free SVG charts for the Analytics dashboard.
// Colours come from CSS tokens so they follow light/dark mode.

// Round axis maximum up to a "nice" value so the 4 gridline steps are readable numbers.
function niceMax(v) {
  const raw = Math.max(v, 4) / 4;
  const mag = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 1.5, 2, 2.5, 3, 4, 5, 10].find((n) => n * mag >= raw) * mag;
  return step * 4;
}

export function BarChart({ data, xKey, yKey, label, color = "var(--c-primary)", height = 200, formatY }) {
  const titleId = useId();
  if (!data || data.length === 0) return <p className="muted">No data for this period yet.</p>;

  const W = 640, padL = 34, padB = 24, padT = 8;
  const max = niceMax(Math.max(1, ...data.map((d) => d[yKey] || 0)));
  const plotW = W - padL, plotH = height - padB - padT;
  const slot = plotW / data.length;
  const barW = Math.max(3, Math.min(22, slot - 4));
  const labelEvery = Math.ceil(data.length / 8);

  return (
    <div className="chart">
      <svg viewBox={`0 0 ${W} ${height}`} role="img" aria-labelledby={titleId} preserveAspectRatio="xMidYMid meet">
        <title id={titleId}>{label}</title>
        {[0, 0.25, 0.5, 0.75, 1].map((t) => {
          const y = padT + plotH * (1 - t);
          return (
            <g key={t}>
              <line className="chart__grid" x1={padL} x2={W} y1={y} y2={y} />
              <text className="chart__axis" x={padL - 8} y={y + 4} textAnchor="end">{Math.round(max * t)}</text>
            </g>
          );
        })}
        {data.map((d, i) => {
          const v = d[yKey] || 0;
          const h = (v / max) * plotH;
          const x = padL + i * slot + (slot - barW) / 2;
          return (
            <g key={i}>
              <rect className="chart__bar" style={{ "--i": i }} x={x} y={padT + plotH - h} width={barW} height={Math.max(h, v > 0 ? 2 : 0)} rx={3} fill={color}>
                <title>{`${d[xKey]}: ${formatY ? formatY(v) : v}`}</title>
              </rect>
              {i % labelEvery === 0 && (
                <text className="chart__axis" x={x + barW / 2} y={height - 6} textAnchor="middle">
                  {String(d[xKey]).slice(5)}
                </text>
              )}
            </g>
          );
        })}
      </svg>
    </div>
  );
}

export function HorizontalBarList({ data, nameKey, valueKey, color = "var(--c-primary)" }) {
  if (!data || data.length === 0) return <p className="muted">No data yet.</p>;
  const max = Math.max(1, ...data.map((d) => d[valueKey] || 0));

  return (
    <div>
      {data.map((d, i) => (
        <div className="hbar" key={i}>
          <div className="hbar__top">
            <span className="truncate">{d[nameKey]}</span>
            <span className="mono muted">{d[valueKey]}</span>
          </div>
          <div className="progress" role="img" aria-label={`${d[nameKey]}: ${d[valueKey]}`}>
            <div className="progress__bar hbar__fill" style={{ width: `${((d[valueKey] || 0) / max) * 100}%`, background: color }} />
          </div>
        </div>
      ))}
    </div>
  );
}
