import { useState, useEffect } from "react";
import api from "../services/api";
import { BarChart, HorizontalBarList } from "../components/MiniCharts";

export default function AnalyticsPage() {
  const [overview, setOverview] = useState(null);
  const [bookingsOverTime, setBookingsOverTime] = useState([]);
  const [userGrowth, setUserGrowth] = useState([]);
  const [topDestinations, setTopDestinations] = useState([]);
  const [guidePerformance, setGuidePerformance] = useState([]);
  const [days, setDays] = useState(30);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchAll = async () => {
    setLoading(true);
    setError(null);
    try {
      const [ov, bot, ug, td, gp] = await Promise.all([
        api.get("/analytics/overview"),
        api.get("/analytics/bookings-over-time", { params: { days } }),
        api.get("/analytics/user-growth", { params: { days } }),
        api.get("/analytics/top-destinations", { params: { limit: 6 } }),
        api.get("/analytics/guide-performance", { params: { limit: 6 } }),
      ]);
      setOverview(ov.data);
      setBookingsOverTime(bot.data);
      setUserGrowth(ug.data);
      setTopDestinations(td.data);
      setGuidePerformance(gp.data);
    } catch (err) {
      console.error(err);
      setError("Failed to load analytics. Is the backend running?");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [days]);

  const cardStyle = {
    background: "#f5f5f5",
    borderRadius: 8,
    padding: 18,
    textAlign: "center",
    flex: "1 1 150px",
    minWidth: 150,
  };
  const sectionStyle = {
    background: "#fff",
    border: "1px solid #eee",
    borderRadius: 8,
    padding: 18,
    marginTop: 20,
  };

  if (loading && !overview) return <p style={{ padding: 20 }}>Loading analytics...</p>;
  if (error) return <p style={{ padding: 20, color: "#c62828" }}>{error}</p>;

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h2>Analytics</h2>
        <div>
          <label style={{ marginRight: 8, color: "#666", fontSize: 14 }}>Range:</label>
          <select value={days} onChange={(e) => setDays(Number(e.target.value))}>
            <option value={7}>Last 7 days</option>
            <option value={30}>Last 30 days</option>
            <option value={90}>Last 90 days</option>
          </select>
        </div>
      </div>

      {/* Overview cards */}
      <div style={{ display: "flex", gap: 14, marginTop: 16, flexWrap: "wrap" }}>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>{overview.totalUsers}</h3>
          <p style={{ margin: 0, color: "#666" }}>Total Users</p>
          <p style={{ margin: 0, fontSize: 12, color: "#999" }}>
            {overview.totalTourists} tourists · {overview.totalGuideUsers} guides
          </p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>{overview.totalBookings}</h3>
          <p style={{ margin: 0, color: "#666" }}>Total Bookings</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0, color: "#2e7d32" }}>LKR {Number(overview.totalRevenue).toLocaleString()}</h3>
          <p style={{ margin: 0, color: "#666" }}>Revenue (Confirmed/Completed)</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>LKR {Number(overview.avgBookingValue).toLocaleString(undefined, { maximumFractionDigits: 0 })}</h3>
          <p style={{ margin: 0, color: "#666" }}>Avg. Booking Value</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0, color: "#ef6c00" }}>{overview.pendingBookings}</h3>
          <p style={{ margin: 0, color: "#666" }}>Pending</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0, color: "#1565c0" }}>{overview.confirmedBookings}</h3>
          <p style={{ margin: 0, color: "#666" }}>Confirmed</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0, color: "#2e7d32" }}>{overview.completedBookings}</h3>
          <p style={{ margin: 0, color: "#666" }}>Completed</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0, color: "#c62828" }}>{overview.cancelledBookings}</h3>
          <p style={{ margin: 0, color: "#666" }}>Cancelled</p>
        </div>
      </div>

      <div style={{ display: "flex", gap: 14, marginTop: 14, flexWrap: "wrap" }}>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>{overview.totalDestinations}</h3>
          <p style={{ margin: 0, color: "#666" }}>Destinations</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>{overview.totalPackages}</h3>
          <p style={{ margin: 0, color: "#666" }}>Packages</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>{overview.totalHotels}</h3>
          <p style={{ margin: 0, color: "#666" }}>Hotels</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>{overview.totalVehicles}</h3>
          <p style={{ margin: 0, color: "#666" }}>Vehicles</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>{overview.totalGuides}</h3>
          <p style={{ margin: 0, color: "#666" }}>Guides</p>
        </div>
      </div>

      {/* Bookings over time */}
      <div style={sectionStyle}>
        <h3 style={{ marginTop: 0 }}>Bookings Over Time</h3>
        <BarChart
          data={bookingsOverTime}
          xKey="date"
          yKey="count"
          label="Bookings over time"
          color="#00897b"
        />
      </div>

      {/* User growth */}
      <div style={sectionStyle}>
        <h3 style={{ marginTop: 0 }}>New User Signups</h3>
        <BarChart
          data={userGrowth}
          xKey="date"
          yKey="newUsers"
          label="New users over time"
          color="#5e35b1"
        />
      </div>

      <div style={{ display: "flex", gap: 14, marginTop: 14, flexWrap: "wrap" }}>
        {/* Top destinations */}
        <div style={{ ...sectionStyle, flex: "1 1 320px", marginTop: 0 }}>
          <h3 style={{ marginTop: 0 }}>Top Destinations (by bookings)</h3>
          <HorizontalBarList data={topDestinations} nameKey="name" valueKey="bookings" color="#00897b" />
        </div>

        {/* Guide performance */}
        <div style={{ ...sectionStyle, flex: "1 1 320px", marginTop: 0 }}>
          <h3 style={{ marginTop: 0 }}>Top Guides (by completed trips)</h3>
          {guidePerformance.length === 0 ? (
            <p style={{ color: "#888" }}>No data yet.</p>
          ) : (
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
              <thead>
                <tr style={{ textAlign: "left", color: "#666", borderBottom: "1px solid #eee" }}>
                  <th style={{ padding: "6px 4px" }}>Guide</th>
                  <th style={{ padding: "6px 4px" }}>Region</th>
                  <th style={{ padding: "6px 4px" }}>Rating</th>
                  <th style={{ padding: "6px 4px" }}>Completed Trips</th>
                </tr>
              </thead>
              <tbody>
                {guidePerformance.map((g) => (
                  <tr key={g.guideId} style={{ borderBottom: "1px solid #f5f5f5" }}>
                    <td style={{ padding: "6px 4px" }}>{g.name}</td>
                    <td style={{ padding: "6px 4px" }}>{g.region}</td>
                    <td style={{ padding: "6px 4px" }}>⭐ {Number(g.rating).toFixed(1)}</td>
                    <td style={{ padding: "6px 4px" }}>{g.completedTrips}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
