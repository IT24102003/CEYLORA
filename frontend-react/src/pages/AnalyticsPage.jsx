//analytics page

import { useState } from "react";
import {
  Banknote, Ban, CalendarCheck, CheckCircle2, Clock, Compass, Hotel, MapPin, Package, Car, Receipt, Users, BadgeCheck, Star,} from "lucide-react";
import api from "../services/api";
import { BarChart, HorizontalBarList } from "../components/MiniCharts";
import { Card, ErrorState, PageHeader, Skeleton, StatCard, Tabs, EmptyState } from "../components/ui";
import { formatLKR, useRemote } from "../lib/hooks";

const RANGES = [
  { value: 7, label: "7 days" },
  { value: 30, label: "30 days" },
  { value: 90, label: "90 days" },
];

async function loadAnalytics(days) {
  const [ov, bot, ug, td, gp] = await Promise.all([
    api.get("/analytics/overview"),
    api.get("/analytics/bookings-over-time", { params: { days } }),
    api.get("/analytics/user-growth", { params: { days } }),
    api.get("/analytics/top-destinations", { params: { limit: 6 } }),
    api.get("/analytics/guide-performance", { params: { limit: 6 } }),
  ]);
  return { overview: ov.data, bookingsOverTime: bot.data, userGrowth: ug.data, topDestinations: td.data, guidePerformance: gp.data };
}

function LoadingSkeleton() {
  return (
    <div aria-busy="true" aria-label="Loading analytics">
      <div className="stat-grid">
        {Array.from({ length: 8 }, (_, i) => (
          <Card key={i} className="stat"><Skeleton w="50%" h={12} /><Skeleton w="70%" h={28} style={{ marginTop: 16 }} /></Card>
        ))}
      </div>
      <div className="dash-grid">
        <Card pad><Skeleton h={220} /></Card>
        <Card pad><Skeleton h={220} /></Card>
      </div>
    </div>
  );
}

export default function AnalyticsPage() {
  const [days, setDays] = useState(30);
  const { data, loading, error, reload } = useRemote(() => loadAnalytics(days), [days]);

  const rangePicker = <Tabs label="Date range" tabs={RANGES} value={days} onChange={setDays} />;

  if (error && !data) {
    return (
      <div className="page">
        <PageHeader title="Analytics" />
        <Card><ErrorState text="We couldn't load analytics. Check that the backend is running and try again." onRetry={reload} /></Card>
      </div>
    );
  }

  const o = data?.overview;
  const first = !data && loading;

  return (
    <div className="page">
      <PageHeader title="Analytics" subtitle="How bookings, revenue and community are trending across Ceylora." actions={rangePicker} />

      {first ? (
        <LoadingSkeleton />
      ) : (
        <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          <div className="stat-grid">
            <StatCard label="Revenue" icon={Banknote} tone="success" value={formatLKR(o.totalRevenue)} note="Confirmed & completed bookings" />
            <StatCard label="Total bookings" icon={CalendarCheck} value={o.totalBookings} />
            <StatCard label="Total users" icon={Users} value={o.totalUsers} note={`${o.totalTourists} tourists · ${o.totalGuideUsers} guides`} />
            <StatCard label="Pending" icon={Clock} tone="warning" value={o.pendingBookings} note="Awaiting action" />
            <StatCard label="Confirmed" icon={BadgeCheck} value={o.confirmedBookings} />
            <StatCard label="Completed" icon={CheckCircle2} tone="success" value={o.completedBookings} />
            <StatCard label="Cancelled" icon={Ban} tone="danger" value={o.cancelledBookings} />
            <StatCard label="Avg. booking" icon={Receipt} tone="accent" value={formatLKR(o.avgBookingValue)} />
          </div>

          <h2 className="section-title" style={{ marginTop: "var(--space-8)" }}>Catalog</h2>
          <div className="stat-grid" style={{ gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))" }}>
            <StatCard label="Destinations" icon={MapPin} value={o.totalDestinations} />
            <StatCard label="Packages" icon={Package} value={o.totalPackages} />
            <StatCard label="Hotels" icon={Hotel} value={o.totalHotels} />
            <StatCard label="Vehicles" icon={Car} value={o.totalVehicles} />
            <StatCard label="Guides" icon={Compass} value={o.totalGuides} />
          </div>

          <div className="dash-grid">
            <Card pad>
              <div className="card__head"><h2 className="card__title">Bookings over time</h2></div>
              <BarChart data={data.bookingsOverTime} xKey="date" yKey="count" label="Bookings over time" color="var(--c-primary)" />
            </Card>
            <Card pad>
              <div className="card__head"><h2 className="card__title">New user signups</h2></div>
              <BarChart data={data.userGrowth} xKey="date" yKey="newUsers" label="New users over time" color="var(--c-accent)" />
            </Card>
            <Card pad>
              <div className="card__head"><h2 className="card__title">Top destinations</h2><span className="card__sub">by bookings</span></div>
              <HorizontalBarList data={data.topDestinations} nameKey="name" valueKey="bookings" />
            </Card>
            <Card pad>
              <div className="card__head"><h2 className="card__title">Top guides</h2><span className="card__sub">by completed trips</span></div>
              {data.guidePerformance.length === 0 ? (
                <EmptyState icon={Compass} title="No guide activity yet" text="Completed trips will rank your guides here." />
              ) : (
                <div className="table-wrap">
                  <table className="dt" style={{ fontSize: "var(--fs-sm)" }}>
                    <thead>
                      <tr><th>Guide</th><th>Region</th><th>Rating</th><th>Trips</th></tr>
                    </thead>
                    <tbody>
                      {data.guidePerformance.map((g) => (
                        <tr key={g.guideId}>
                          <td data-label="Guide" className="cell-primary"><strong>{g.name}</strong></td>
                          <td data-label="Region">{g.region}</td>
                          <td data-label="Rating"><span className="row" style={{ gap: 4 }}><Star size={13} fill="currentColor" style={{ color: "var(--c-warning)" }} aria-hidden="true" />{Number(g.rating).toFixed(1)}</span></td>
                          <td data-label="Trips" className="mono">{g.completedTrips}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>
          </div>
        </div>
      )}
    </div>
  );
}
