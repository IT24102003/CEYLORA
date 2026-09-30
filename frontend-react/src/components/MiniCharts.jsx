// Small dependency-free SVG charts for the Analytics dashboard.
// Kept intentionally simple (no charting library) so the project needs no extra npm install.

export function BarChart({ data, xKey, yKey, label, color = "#00897b", height = 180, formatY }) {
  if (!data || data.length === 0) return <p style={{ color: "#888" }}>No data yet.</p>;

  const max = Math.max(1, ...data.map((d) => d[yKey] || 0));
  const width = Math.max(320, data.length * 28);
  const barWidth = Math.min(24, (width / data.length) - 6);

  return (
    <div style={{ overflowX: "auto" }}>
      <svg width={width} height={height + 30} role="img" aria-label={label}>
        {data.map((d, i) => {
          const barHeight = ((d[yKey] || 0) / max) * height;
          const x = i * (width / data.length) + 3;
          const y = height - barHeight;
          return (
            <g key={i}>
              <title>{`${d[xKey]}: ${formatY ? formatY(d[yKey]) : d[yKey]}`}</title>
              <rect x={x} y={y} width={barWidth} height={barHeight} fill={color} rx={3} />
              {data.length <= 14 && (
                <text
                  x={x + barWidth / 2}
                  y={height + 16}
                  fontSize="10"
                  textAnchor="middle"
                  fill="#666"
                >
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

export function HorizontalBarList({ data, nameKey, valueKey, color = "#00897b" }) {
  if (!data || data.length === 0) return <p style={{ color: "#888" }}>No data yet.</p>;
  const max = Math.max(1, ...data.map((d) => d[valueKey] || 0));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      {data.map((d, i) => (
        <div key={i}>
          <div style={{ display: "flex", justifyContent: "space-between", fontSize: 13, marginBottom: 3 }}>
            <span>{d[nameKey]}</span>
            <span style={{ color: "#666" }}>{d[valueKey]}</span>
          </div>
          <div style={{ background: "#eee", borderRadius: 4, height: 10 }}>
            <div
              style={{
                width: `${((d[valueKey] || 0) / max) * 100}%`,
                background: color,
                height: "100%",
                borderRadius: 4,
                transition: "width 0.3s",
              }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}
