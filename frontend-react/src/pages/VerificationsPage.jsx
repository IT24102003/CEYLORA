import { useState, useEffect } from "react";
import api from "../services/api";

const API_ROOT = "http://localhost:5220"; // for viewing uploaded document/vehicle photos

export default function VerificationsPage() {
  const [pendingGuides, setPendingGuides] = useState([]);
  const [pendingOwners, setPendingOwners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);
  const [noteDrafts, setNoteDrafts] = useState({});

  const fetchAll = async () => {
    setLoading(true);
    try {
      const [g, v] = await Promise.all([
        api.get("/guides/pending"),
        api.get("/vehicle-owners/pending"),
      ]);
      setPendingGuides(g.data);
      setPendingOwners(v.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAll();
  }, []);

  const handleVerifyGuide = async (id, approve) => {
    setBusyId(`guide-${id}`);
    try {
      await api.put(`/guides/${id}/verify`, { approve, note: noteDrafts[`guide-${id}`] || null });
      fetchAll();
    } catch (err) {
      alert("Failed to update verification status.");
    } finally {
      setBusyId(null);
    }
  };

  const handleVerifyOwner = async (id, approve) => {
    setBusyId(`owner-${id}`);
    try {
      await api.put(`/vehicle-owners/${id}/verify`, { approve, note: noteDrafts[`owner-${id}`] || null });
      fetchAll();
    } catch (err) {
      alert("Failed to update verification status.");
    } finally {
      setBusyId(null);
    }
  };

  const cardStyle = {
    background: "#fff",
    border: "1px solid #eee",
    borderRadius: 8,
    padding: 16,
    marginBottom: 14,
  };
  const labelStyle = { fontSize: 12, color: "#888" };
  const docLinkStyle = {
    display: "inline-block",
    marginTop: 4,
    marginRight: 8,
    color: "#1565c0",
    fontSize: 13,
  };

  if (loading) return <p style={{ padding: 20 }}>Loading pending applications...</p>;

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Verifications</h2>
      <p style={{ color: "#666" }}>
        Guide and Vehicle Owner accounts wait here until you review their details and documents.
      </p>

      <h3 style={{ marginTop: 24 }}>
        Pending Guides {pendingGuides.length > 0 && <span style={{ color: "#ef6c00" }}>({pendingGuides.length})</span>}
      </h3>
      {pendingGuides.length === 0 ? (
        <p style={{ color: "#888" }}>No pending guide applications.</p>
      ) : (
        pendingGuides.map((g) => (
          <div key={g.id} style={cardStyle}>
            <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 16 }}>
              <div>
                <strong>{g.name}</strong> — {g.email}
                <div style={labelStyle}>
                  Age {g.age ?? "—"} · {g.region} · Country: {g.country ?? "—"} · NIC: {g.nicNumber ?? "—"} · Phone: {g.mobileNumber ?? "—"}
                  {g.languages && <> · Languages: {g.languages}</>}
                </div>
                {g.tourismIdPhotoUrl && (
                  <a
                    href={`${API_ROOT}${g.tourismIdPhotoUrl}`}
                    target="_blank"
                    rel="noreferrer"
                    style={docLinkStyle}
                  >
                    📄 View Tourism ID
                  </a>
                )}
                <div style={{ marginTop: 8 }}>
                  <input
                    placeholder="Rejection reason (optional)"
                    value={noteDrafts[`guide-${g.id}`] || ""}
                    onChange={(e) => setNoteDrafts((s) => ({ ...s, [`guide-${g.id}`]: e.target.value }))}
                    style={{ padding: 6, width: 260 }}
                  />
                </div>
              </div>
              <div style={{ display: "flex", gap: 8, alignItems: "flex-start" }}>
                <button
                  disabled={busyId === `guide-${g.id}`}
                  onClick={() => handleVerifyGuide(g.id, true)}
                  style={{ background: "#2e7d32", color: "#fff", border: "none", padding: "6px 14px", borderRadius: 4 }}
                >
                  Approve
                </button>
                <button
                  disabled={busyId === `guide-${g.id}`}
                  onClick={() => handleVerifyGuide(g.id, false)}
                  style={{ background: "#c62828", color: "#fff", border: "none", padding: "6px 14px", borderRadius: 4 }}
                >
                  Reject
                </button>
              </div>
            </div>
          </div>
        ))
      )}

      <h3 style={{ marginTop: 32 }}>
        Pending Vehicle Owners {pendingOwners.length > 0 && <span style={{ color: "#ef6c00" }}>({pendingOwners.length})</span>}
      </h3>
      {pendingOwners.length === 0 ? (
        <p style={{ color: "#888" }}>No pending vehicle owner applications.</p>
      ) : (
        pendingOwners.map((o) => (
          <div key={o.id} style={cardStyle}>
            <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 16 }}>
              <div>
                <strong>{o.name}</strong> — {o.email}
                <div style={labelStyle}>
                  Age {o.age ?? "—"} · {o.region} · Country: {o.country ?? "—"} · NIC: {o.nicNumber ?? "—"} · Phone: {o.mobileNumber ?? "—"}
                </div>
                {o.drivingLicensePhotoUrl && (
                  <a
                    href={`${API_ROOT}${o.drivingLicensePhotoUrl}`}
                    target="_blank"
                    rel="noreferrer"
                    style={docLinkStyle}
                  >
                    📄 View License
                  </a>
                )}
                {o.vehicles?.map((v) => (
                  <div key={v.id} style={{ marginTop: 8, fontSize: 13 }}>
                    <strong>Vehicle:</strong> {v.name} ({v.type}, {v.manufacturerYear}, {v.capacity} seats)
                    <div>
                      {v.images?.map((img, i) => (
                        <a
                          key={i}
                          href={`${API_ROOT}${img}`}
                          target="_blank"
                          rel="noreferrer"
                          style={docLinkStyle}
                        >
                          🚗 Photo {i + 1}
                        </a>
                      ))}
                    </div>
                  </div>
                ))}
                <div style={{ marginTop: 8 }}>
                  <input
                    placeholder="Rejection reason (optional)"
                    value={noteDrafts[`owner-${o.id}`] || ""}
                    onChange={(e) => setNoteDrafts((s) => ({ ...s, [`owner-${o.id}`]: e.target.value }))}
                    style={{ padding: 6, width: 260 }}
                  />
                </div>
              </div>
              <div style={{ display: "flex", gap: 8, alignItems: "flex-start" }}>
                <button
                  disabled={busyId === `owner-${o.id}`}
                  onClick={() => handleVerifyOwner(o.id, true)}
                  style={{ background: "#2e7d32", color: "#fff", border: "none", padding: "6px 14px", borderRadius: 4 }}
                >
                  Approve
                </button>
                <button
                  disabled={busyId === `owner-${o.id}`}
                  onClick={() => handleVerifyOwner(o.id, false)}
                  style={{ background: "#c62828", color: "#fff", border: "none", padding: "6px 14px", borderRadius: 4 }}
                >
                  Reject
                </button>
              </div>
            </div>
          </div>
        ))
      )}
    </div>
  );
}
