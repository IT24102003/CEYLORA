import { useState, useEffect } from "react";
import api from "../services/api";

const STATUS_OPTIONS = ["Pending", "Confirmed", "Cancelled", "Completed"];

export default function BookingsPage() {
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("");

  const fetchBookings = async () => {
    setLoading(true);
    try {
      const params = { pageSize: 50 };
      if (statusFilter) params.status = statusFilter;
      const res = await api.get("/bookings", { params });
      setBookings(res.data.items);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBookings();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [statusFilter]);

  const handleStatusChange = async (id, newStatus) => {
    try {
      await api.put(`/bookings/${id}/status`, { status: newStatus });
      fetchBookings();
    } catch (err) {
      alert(err.response?.data?.message || "Failed to update status.");
    }
  };

  const handleDelete = async (id) => {
    if (!confirm("Delete this booking?")) return;
    try {
      await api.delete(`/bookings/${id}`);
      fetchBookings();
    } catch (err) {
      alert("Failed to delete.");
    }
  };

  const statusColor = (status) => {
    const s = STATUS_OPTIONS[status] ?? status;
    switch (s) {
      case "Confirmed": return "#2e7d32";
      case "Cancelled": return "#c62828";
      case "Completed": return "#1565c0";
      default: return "#ef6c00"; // Pending
    }
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Bookings</h2>

      <div style={{ marginBottom: 16 }}>
        <label>Filter by status: </label>
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} style={{ padding: 6 }}>
          <option value="">All</option>
          {STATUS_OPTIONS.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
      </div>

      {loading ? (
        <p>Loading...</p>
      ) : bookings.length === 0 ? (
        <p>No bookings found.</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr style={{ borderBottom: "2px solid #ccc", textAlign: "left" }}>
              <th style={{ padding: 8 }}>ID</th>
              <th style={{ padding: 8 }}>Package</th>
              <th style={{ padding: 8 }}>Total Price</th>
              <th style={{ padding: 8 }}>Status</th>
              <th style={{ padding: 8 }}>Created</th>
              <th style={{ padding: 8 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {bookings.map((b) => {
              const statusLabel = typeof b.status === "number" ? STATUS_OPTIONS[b.status] : b.status;
              return (
                <tr key={b.id} style={{ borderBottom: "1px solid #eee" }}>
                  <td style={{ padding: 8 }}>#{b.id}</td>
                  <td style={{ padding: 8 }}>{b.package?.name ?? `Package #${b.packageId}`}</td>
                  <td style={{ padding: 8 }}>LKR {b.totalPrice}</td>
                  <td style={{ padding: 8 }}>
                    <span style={{ background: statusColor(b.status), color: "#fff", padding: "3px 10px", borderRadius: 4, fontSize: 13 }}>
                      {statusLabel}
                    </span>
                  </td>
                  <td style={{ padding: 8 }}>{new Date(b.createdAt).toLocaleDateString()}</td>
                  <td style={{ padding: 8 }}>
                    <select
                      defaultValue=""
                      onChange={(e) => {
                        if (e.target.value) handleStatusChange(b.id, e.target.value);
                        e.target.value = "";
                      }}
                      style={{ marginRight: 8, padding: 4 }}
                    >
                      <option value="">Change status...</option>
                      {STATUS_OPTIONS.map((s) => (
                        <option key={s} value={s}>{s}</option>
                      ))}
                    </select>
                    <button onClick={() => handleDelete(b.id)} style={{ color: "red" }}>Delete</button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}