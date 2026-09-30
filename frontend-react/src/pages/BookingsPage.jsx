import { useState, useEffect } from "react";
import api from "../services/api";

// 🔥 Must match the backend's BookingStatus enum order exactly (Booking.cs) — the numeric
// `status` value returned by the API is an index into this array.
const STATUS_OPTIONS = ["Pending", "Confirmed", "Cancelled", "Ended", "OnGoing", "Rejected"];

// Tabs the admin asked for: Pending / OnGoing / Ended / Rejected / Cancelled, plus an
// "All" tab. "Confirmed" (assigned but trip not started yet) is folded into OnGoing's
// neighbourhood but kept filterable via "All" since it's a real status too.
const TABS = ["All", "Pending", "Confirmed", "OnGoing", "Ended", "Rejected", "Cancelled"];

export default function BookingsPage() {
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState("Pending");

  // Assign guide+vehicle modal state
  const [assigningBooking, setAssigningBooking] = useState(null); // the booking object
  const [availableGuides, setAvailableGuides] = useState([]);
  const [availableVehicles, setAvailableVehicles] = useState([]);
  const [pickedGuideId, setPickedGuideId] = useState("");
  const [pickedVehicleId, setPickedVehicleId] = useState("");
  const [assignError, setAssignError] = useState("");
  const [assignSubmitting, setAssignSubmitting] = useState(false);

  const fetchBookings = async () => {
    setLoading(true);
    try {
      const params = { pageSize: 50 };
      if (tab !== "All") params.status = tab;
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
  }, [tab]);

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

  const openAssignModal = async (booking) => {
    setAssigningBooking(booking);
    setPickedGuideId("");
    setPickedVehicleId("");
    setAssignError("");
    try {
      const [guidesRes, vehiclesRes] = await Promise.all([
        api.get("/guides", { params: { available: true, pageSize: 100 } }),
        api.get("/vehicles", { params: { available: true, pageSize: 100 } }),
      ]);
      setAvailableGuides(guidesRes.data.items ?? []);
      // Only offer vehicles big enough to seat the whole group.
      const vehicles = (vehiclesRes.data.items ?? []).filter((v) => v.capacity >= (booking.groupSize || 1));
      setAvailableVehicles(vehicles);
    } catch (err) {
      setAssignError("Failed to load available guides/vehicles.");
    }
  };

  const closeAssignModal = () => setAssigningBooking(null);

  const submitAssign = async () => {
    if (!pickedGuideId || !pickedVehicleId) {
      setAssignError("Please select both a guide and a vehicle.");
      return;
    }
    setAssignSubmitting(true);
    setAssignError("");
    try {
      await api.post("/assignments/assign-confirm", {
        bookingId: assigningBooking.id,
        guideId: Number(pickedGuideId),
        vehicleId: Number(pickedVehicleId),
      });
      closeAssignModal();
      fetchBookings();
    } catch (err) {
      setAssignError(err.response?.data?.message || "Failed to assign & confirm.");
    } finally {
      setAssignSubmitting(false);
    }
  };

  const statusColor = (status) => {
    const s = STATUS_OPTIONS[status] ?? status;
    switch (s) {
      case "Confirmed": return "#2e7d32";
      case "OnGoing": return "#00897b";
      case "Ended": return "#1565c0";
      case "Cancelled": return "#9e9e9e";
      case "Rejected": return "#c62828";
      default: return "#ef6c00"; // Pending
    }
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Bookings</h2>

      <div style={{ display: "flex", gap: 6, marginBottom: 16, flexWrap: "wrap" }}>
        {TABS.map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            style={{
              padding: "8px 16px",
              border: "1px solid #ccc",
              borderRadius: 20,
              background: tab === t ? "#1565c0" : "#fff",
              color: tab === t ? "#fff" : "#333",
              cursor: "pointer",
              fontSize: 13,
            }}
          >
            {t}
          </button>
        ))}
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
              <th style={{ padding: 8 }}>Tourist</th>
              <th style={{ padding: 8 }}>Package</th>
              <th style={{ padding: 8 }}>Group</th>
              <th style={{ padding: 8 }}>Guide</th>
              <th style={{ padding: 8 }}>Vehicle</th>
              <th style={{ padding: 8 }}>Total Cost</th>
              <th style={{ padding: 8 }}>Paid</th>
              <th style={{ padding: 8 }}>Status</th>
              <th style={{ padding: 8 }}>Created</th>
              <th style={{ padding: 8 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {bookings.map((b) => {
              const statusLabel = typeof b.status === "number" ? STATUS_OPTIONS[b.status] : b.status;
              const needsAssignment = statusLabel === "Pending" && b.packageId && !b.guideName && !b.vehicleName && b.isPaid;
              const awaitingPayment = statusLabel === "Pending" && b.packageId && !b.isPaid;
              return (
                <tr key={b.id} style={{ borderBottom: "1px solid #eee" }}>
                  <td style={{ padding: 8 }}>#{b.id}</td>
                  <td style={{ padding: 8 }}>
                    <div>{b.tourist?.name ?? `User #${b.touristId}`}</div>
                    <div style={{ fontSize: 11, color: "#888" }}>{b.tourist?.mobileNumber ?? b.tourist?.email ?? ""}</div>
                  </td>
                  <td style={{ padding: 8 }}>{b.packageName ?? `Package #${b.packageId}`}</td>
                  <td style={{ padding: 8 }}>{b.groupSize ?? 1}</td>
                  <td style={{ padding: 8 }}>{b.guideName ?? "—"}</td>
                  <td style={{ padding: 8 }}>{b.vehicleName ?? "—"}</td>
                  <td style={{ padding: 8 }}>LKR {Number(b.totalPrice).toLocaleString()}</td>
                  <td style={{ padding: 8 }}>
                    <span style={{ background: b.isPaid ? "#2e7d32" : "#c62828", color: "#fff", padding: "3px 10px", borderRadius: 4, fontSize: 12 }}>
                      {b.isPaid ? "Paid" : "Unpaid"}
                    </span>
                  </td>
                  <td style={{ padding: 8 }}>
                    <span style={{ background: statusColor(b.status), color: "#fff", padding: "3px 10px", borderRadius: 4, fontSize: 13 }}>
                      {statusLabel}
                    </span>
                  </td>
                  <td style={{ padding: 8 }}>{new Date(b.createdAt).toLocaleDateString()}</td>
                  <td style={{ padding: 8 }}>
                    {needsAssignment && (
                      <button
                        onClick={() => openAssignModal(b)}
                        style={{ marginRight: 8, background: "#2b62d9", color: "#fff", border: "none", padding: "5px 10px", borderRadius: 4, fontSize: 12 }}
                      >
                        Assign & Confirm
                      </button>
                    )}
                    {awaitingPayment && (
                      <span style={{ marginRight: 8, fontSize: 12, color: "#c62828" }}>Awaiting payment</span>
                    )}
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

      {assigningBooking && (
        <div
          style={{
            position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)",
            display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1000,
          }}
          onClick={closeAssignModal}
        >
          <div
            style={{ background: "#fff", borderRadius: 8, padding: 24, width: 420, maxWidth: "90%" }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ marginTop: 0 }}>Assign Guide & Vehicle — Booking #{assigningBooking.id}</h3>
            <p style={{ color: "#666", fontSize: 13 }}>
              Group size: {assigningBooking.groupSize ?? 1} — only vehicles that can seat this many are listed.
            </p>

            {assignError && <p style={{ color: "#c62828", fontSize: 13 }}>{assignError}</p>}

            <label style={{ fontSize: 13, fontWeight: 600 }}>Guide</label>
            <select
              value={pickedGuideId}
              onChange={(e) => setPickedGuideId(e.target.value)}
              style={{ display: "block", width: "100%", padding: 8, marginTop: 4, marginBottom: 12 }}
            >
              <option value="">Select a guide...</option>
              {availableGuides.map((g) => (
                <option key={g.id} value={g.id}>
                  {g.name ?? `Guide #${g.id}`} — {g.region} (⭐ {Number(g.rating ?? 0).toFixed(1)})
                </option>
              ))}
            </select>
            {availableGuides.length === 0 && <p style={{ fontSize: 12, color: "#999" }}>No available guides right now.</p>}

            <label style={{ fontSize: 13, fontWeight: 600 }}>Vehicle</label>
            <select
              value={pickedVehicleId}
              onChange={(e) => setPickedVehicleId(e.target.value)}
              style={{ display: "block", width: "100%", padding: 8, marginTop: 4, marginBottom: 16 }}
            >
              <option value="">Select a vehicle...</option>
              {availableVehicles.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.name ?? v.type} — seats {v.capacity} — {v.region}
                </option>
              ))}
            </select>
            {availableVehicles.length === 0 && <p style={{ fontSize: 12, color: "#999" }}>No available vehicle seats this many people.</p>}

            <div style={{ display: "flex", justifyContent: "flex-end", gap: 8 }}>
              <button onClick={closeAssignModal} style={{ padding: "8px 16px" }}>Cancel</button>
              <button
                onClick={submitAssign}
                disabled={assignSubmitting}
                style={{ padding: "8px 16px", background: "#2e7d32", color: "#fff", border: "none", borderRadius: 4 }}
              >
                {assignSubmitting ? "Confirming..." : "Confirm Trip"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
