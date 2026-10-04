import { useMemo, useState } from "react";
import { Copy, Download, FileText, Printer, TrendingDown, TrendingUp, Minus } from "lucide-react";
import api from "../services/api";
import { BarChart, HorizontalBarList } from "../components/MiniCharts";
import { Button, Card, ErrorState, PageHeader, Select, Skeleton, useToast } from "../components/ui";
import { formatLKR, useRemote } from "../lib/hooks";

// Must match the backend's BookingStatus enum order .
const STATUS = ["Pending", "Confirmed", "Cancelled", "Ended", "OnGoing", "Rejected"];
const statusName = (s) => (typeof s === "number" ? STATUS[s] : s);

const WEEK_OPTIONS = [
  { value: 0, label: "Last 7 days" },
  { value: 1, label: "Previous week" },
  { value: 2, label: "2 weeks ago" },
  { value: 3, label: "3 weeks ago" },
];

const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
const addDays = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
const pretty = (s) => new Date(`${s}T00:00:00`).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" });

/** The 7 calendar days of the chosen week (offset 0 = the 7 days ending today). */
function weekDays(offset) {
  const end = addDays(new Date(), -7 * offset);
  return Array.from({ length: 7 }, (_, i) => ymd(addDays(end, i - 6)));
}

async function loadReport(offset) {
  // The analytics endpoints are relative to "now", so ask for enough days to cover this week and the one before it.
  const span = 7 * (offset + 2);
  const [ov, bot, ug, td, gp, bk] = await Promise.all([
    api.get("/analytics/overview"),
    api.get("/analytics/bookings-over-time", { params: { days: span } }),
    api.get("/analytics/user-growth", { params: { days: span } }),
    api.get("/analytics/top-destinations", { params: { limit: 5 } }),
    api.get("/analytics/guide-performance", { params: { limit: 5 } }),
    api.get("/bookings", { params: { pageSize: 200 } }),
  ]);
  return { overview: ov.data, bookingsOverTime: bot.data, userGrowth: ug.data, topDestinations: td.data, guides: gp.data, bookings: bk.data.items ?? [] };
}

const sumBy = (rows, key, days) => rows.filter((r) => days.includes(String(r.date).slice(0, 10))).reduce((a, r) => a + (r[key] || 0), 0);

function buildReport(raw, offset) {
  const days = weekDays(offset);
  const prevDays = weekDays(offset + 1);
  const inWeek = (b, set) => set.includes(String(b.createdAt).slice(0, 10));
  const weekBookings = raw.bookings.filter((b) => inWeek(b, days));
  const prevBookings = raw.bookings.filter((b) => inWeek(b, prevDays));
  const revenue = (list) => list.filter((b) => b.isPaid).reduce((a, b) => a + Number(b.totalPrice || 0), 0);

  const statusCounts = STATUS.map((s) => ({ name: s, count: weekBookings.filter((b) => statusName(b.status) === s).length })).filter((s) => s.count > 0);
  const daily = days.map((d) => ({
    date: d,
    bookings: raw.bookingsOverTime.find((r) => String(r.date).slice(0, 10) === d)?.count ?? 0,
    users: raw.userGrowth.find((r) => String(r.date).slice(0, 10) === d)?.newUsers ?? 0,
  }));

  const kpis = [
    { key: "bookings", label: "New bookings", value: sumBy(raw.bookingsOverTime, "count", days), prev: sumBy(raw.bookingsOverTime, "count", prevDays), fmt: (v) => v },
    { key: "users", label: "New users", value: sumBy(raw.userGrowth, "newUsers", days), prev: sumBy(raw.userGrowth, "newUsers", prevDays), fmt: (v) => v },
    { key: "revenue", label: "Paid revenue", value: revenue(weekBookings), prev: revenue(prevBookings), fmt: (v) => formatLKR(v) },
    { key: "avg", label: "Avg. booking value", value: weekBookings.length ? weekBookings.reduce((a, b) => a + Number(b.totalPrice || 0), 0) / weekBookings.length : 0, prev: prevBookings.length ? prevBookings.reduce((a, b) => a + Number(b.totalPrice || 0), 0) / prevBookings.length : 0, fmt: (v) => formatLKR(v) },
  ];
  return { days, daily, kpis, statusCounts, weekBookings, overview: raw.overview, topDestinations: raw.topDestinations, guides: raw.guides };
}

function delta(value, prev) {
  if (!prev && !value) return { pct: 0, dir: "flat" };
  if (!prev) return { pct: null, dir: "up" };
  const pct = ((value - prev) / prev) * 100;
  return { pct, dir: pct > 0.5 ? "up" : pct < -0.5 ? "down" : "flat" };
}

function summaryText(r) {
  const [from, to] = [r.days[0], r.days[6]];
  const lines = [`Ceylora weekly report — ${pretty(from)} to ${pretty(to)}`, ""];
  r.kpis.forEach((k) => {
    const d = delta(k.value, k.prev);
    const change = d.pct == null ? "new" : `${d.pct >= 0 ? "+" : ""}${d.pct.toFixed(0)}% vs previous week`;
    lines.push(`• ${k.label}: ${k.fmt(k.value)} (${change})`);
  });
  if (r.statusCounts.length) lines.push("", "Booking status: " + r.statusCounts.map((s) => `${s.name} ${s.count}`).join(", "));
  if (r.topDestinations.length) lines.push("", "Top destinations (all time): " + r.topDestinations.map((d) => `${d.name} (${d.bookings})`).join(", "));
  return lines.join("\n");
}

function csvOf(r) {
  const q = (v) => `"${String(v).replace(/"/g, '""')}"`;
  const rows = [["Metric", "This week", "Previous week"], ...r.kpis.map((k) => [k.label, k.value, k.prev]), [], ["Date", "Bookings", "New users"], ...r.daily.map((d) => [d.date, d.bookings, d.users])];
  return rows.map((row) => row.map(q).join(",")).join("\n");
}

function Delta({ value, prev }) {
  const d = delta(value, prev);
  const Icon = d.dir === "up" ? TrendingUp : d.dir === "down" ? TrendingDown : Minus;
  const tone = d.dir === "up" ? "var(--c-success)" : d.dir === "down" ? "var(--c-danger)" : "var(--c-text-3)";
  return (
    <span className="row" style={{ gap: 4, color: tone, fontSize: "var(--fs-sm)", fontWeight: 600 }}>
      <Icon size={14} aria-hidden="true" />
      {d.pct == null ? "New" : `${d.pct >= 0 ? "+" : ""}${d.pct.toFixed(0)}%`}
      <span className="muted" style={{ fontWeight: 400 }}>vs prev. week</span>
    </span>
  );
}

export default function ReportsPage() {
  const [offset, setOffset] = useState(0);
  const toast = useToast();
  const { data, loading, error, reload } = useRemote(() => loadReport(offset), [offset]);
  const report = useMemo(() => (data ? buildReport(data, offset) : null), [data, offset]);

  const copy = async () => {
    try { await navigator.clipboard.writeText(summaryText(report)); toast.success("Summary copied to clipboard."); }
    catch { toast.error("Couldn't copy — your browser blocked clipboard access."); }
  };
  const download = () => {
    const blob = new Blob([csvOf(report)], { type: "text/csv;charset=utf-8" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `ceylora-weekly-report-${report.days[6]}.csv`;
    a.click();
    URL.revokeObjectURL(a.href);
    toast.success("CSV downloaded.");
  };

  const actions = (
    <>
      <Select aria-label="Report week" value={offset} onChange={(e) => setOffset(Number(e.target.value))} options={WEEK_OPTIONS} />
      <Button icon={Copy} onClick={copy} disabled={!report}>Copy summary</Button>
      <Button icon={Download} onClick={download} disabled={!report}>CSV</Button>
      <Button variant="primary" icon={Printer} onClick={() => window.print()} disabled={!report}>Print / PDF</Button>
    </>
  );

  if (error && !data) {
    return (
      <div className="page">
        <PageHeader title="Weekly report" />
        <Card><ErrorState text="The report data could not be loaded. Check that the backend is running." onRetry={reload} /></Card>
      </div>
    );
  }

  return (
    <div className="page report">
      <PageHeader
        title="Weekly report"
        subtitle={report ? `${pretty(report.days[0])} – ${pretty(report.days[6])}` : "Preparing your report…"}
        actions={<div className="report__actions">{actions}</div>}
      />

      {!report ? (
        <div className="stat-grid" aria-busy="true">
          {Array.from({ length: 4 }, (_, i) => <Card key={i} className="stat"><Skeleton w="50%" h={12} /><Skeleton w="70%" h={28} style={{ marginTop: 16 }} /></Card>)}
        </div>
      ) : (
        <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          <div className="report__print-title">
            <FileText size={18} aria-hidden="true" /> Ceylora weekly report · {pretty(report.days[0])} – {pretty(report.days[6])}
          </div>

          <div className="stat-grid">
            {report.kpis.map((k) => (
              <Card key={k.key} className="stat">
                <div className="stat__top"><span>{k.label}</span></div>
                <div className="stat__value">{k.fmt(k.value)}</div>
                <div className="stat__note"><Delta value={k.value} prev={k.prev} /></div>
              </Card>
            ))}
          </div>

          <div className="dash-grid">
            <Card pad>
              <div className="card__head"><h2 className="card__title">Bookings per day</h2></div>
              <BarChart data={report.daily.map((d) => ({ date: d.date, count: d.bookings }))} xKey="date" yKey="count" label="Bookings per day" />
            </Card>
            <Card pad>
              <div className="card__head"><h2 className="card__title">New users per day</h2></div>
              <BarChart data={report.daily.map((d) => ({ date: d.date, newUsers: d.users }))} xKey="date" yKey="newUsers" label="New users per day" color="var(--c-accent)" />
            </Card>
            <Card pad>
              <div className="card__head"><h2 className="card__title">Booking status</h2><span className="card__sub">bookings created this week</span></div>
              {report.statusCounts.length === 0 ? <p className="muted">No bookings were created this week.</p> : (
                <HorizontalBarList data={report.statusCounts} nameKey="name" valueKey="count" />
              )}
            </Card>
            <Card pad>
              <div className="card__head"><h2 className="card__title">Top destinations</h2><span className="card__sub">all time</span></div>
              <HorizontalBarList data={report.topDestinations} nameKey="name" valueKey="bookings" />
            </Card>
          </div>

          <Card pad style={{ marginTop: "var(--space-4)" }}>
            <div className="card__head"><h2 className="card__title">Top guides</h2><span className="card__sub">by completed trips</span></div>
            {report.guides.length === 0 ? <p className="muted">No guide activity yet.</p> : (
              <div className="table-wrap">
                <table className="dt" style={{ fontSize: "var(--fs-sm)" }}>
                  <thead><tr><th>Guide</th><th>Region</th><th>Rating</th><th>Completed trips</th></tr></thead>
                  <tbody>
                    {report.guides.map((g) => (
                      <tr key={g.guideId}>
                        <td data-label="Guide" className="cell-primary"><strong>{g.name}</strong></td>
                        <td data-label="Region">{g.region}</td>
                        <td data-label="Rating" className="mono">{Number(g.rating).toFixed(1)}</td>
                        <td data-label="Completed" className="mono">{g.completedTrips}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>

          <p className="muted" style={{ marginTop: "var(--space-4)", fontSize: "var(--fs-xs)" }}>
            Revenue counts paid bookings created in the week (latest 200 bookings are considered). Destination and guide rankings are all-time because the backend doesn't filter them by date.
          </p>
        </div>
      )}
    </div>
  );
}
