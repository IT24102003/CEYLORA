import { useState, useEffect } from "react";
import api from "../services/api";

export default function AnalyticsPage() {
  const [stats, setStats] = useState({
    totalBookings: 0,
    totalRevenue: 0,
    confirmedBookings: 0,
    pendingBookings: 0,
  });
  const [loading, setLoading] = useState(true);

  const fetchStats = async () => {
    setLoading(true);
    try {
      const res = await api.get("/bookings", { params: { pageSize: 1000 } });
      const bookings = res.data.items;

      const totalRevenue = bookings
        .filter((b) => b.status === 1 || b.status === "Confirmed" || b.status === 3 || b.status === "Completed")
        .reduce((sum, b) => sum + (b.totalPrice || 0), 0);

      setStats({
        totalBookings: bookings.length,
        totalRevenue,
        confirmedBookings: bookings.filter((b) => b.status === 1 || b.status === "Confirmed").length,
        pendingBookings: bookings.filter((b) => b.status === 0 || b.status === "Pending").length,
      });
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  if (loading) return <p style={{ padding: 20 }}>Loading analytics...</p>;

  const cardStyle = {
    background: "#f5f5f5",
    borderRadius: 8,
    padding: 20,
    textAlign: "center",
    flex: 1,
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Analytics</h2>

      <div style={{ display: "flex", gap: 16, marginTop: 20 }}>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>{stats.totalBookings}</h3>
          <p style={{ margin: 0, color: "#666" }}>Total Bookings</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0 }}>LKR {stats.totalRevenue.toLocaleString()}</h3>
          <p style={{ margin: 0, color: "#666" }}>Revenue (Confirmed/Completed)</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0, color: "#2e7d32" }}>{stats.confirmedBookings}</h3>
          <p style={{ margin: 0, color: "#666" }}>Confirmed Bookings</p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ margin: 0, color: "#ef6c00" }}>{stats.pendingBookings}</h3>
          <p style={{ margin: 0, color: "#666" }}>Pending Bookings</p>
        </div>
      </div>
    </div>
  );
}