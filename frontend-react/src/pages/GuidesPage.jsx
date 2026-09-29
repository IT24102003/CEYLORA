import { useState, useEffect } from "react";
import api from "../services/api";

export default function GuidesPage() {
  const [guides, setGuides] = useState([]);
  const [loading, setLoading] = useState(true);
  const [regionFilter, setRegionFilter] = useState("");

  const fetchGuides = async () => {
    setLoading(true);
    try {
      const params = { pageSize: 50 };
      if (regionFilter) params.region = regionFilter;
      const res = await api.get("/guides", { params });
      setGuides(res.data.items);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchGuides();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleToggleAvailability = async (guide) => {
    try {
      await api.put(`/guides/${guide.id}/availability`, !guide.isAvailable);
      fetchGuides();
    } catch (err) {
      alert("Failed to update availability.");
    }
  };

  const handleDelete = async (id) => {
    if (!confirm("Delete this guide?")) return;
    try {
      await api.delete(`/guides/${id}`);
      fetchGuides();
    } catch (err) {
      alert("Failed to delete.");
    }
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Guides</h2>

      <div style={{ marginBottom: 16, display: "flex", gap: 8 }}>
        <input
          placeholder="Filter by region..."
          value={regionFilter}
          onChange={(e) => setRegionFilter(e.target.value)}
          style={{ padding: 8 }}
        />
        <button onClick={fetchGuides} style={{ padding: "8px 16px" }}>Filter</button>
      </div>

      {loading ? (
        <p>Loading...</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr style={{ borderBottom: "2px solid #ccc", textAlign: "left" }}>
              <th style={{ padding: 8 }}>ID</th>
              <th style={{ padding: 8 }}>Languages</th>
              <th style={{ padding: 8 }}>Region</th>
              <th style={{ padding: 8 }}>Rating</th>
              <th style={{ padding: 8 }}>Available</th>
              <th style={{ padding: 8 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {guides.map((g) => (
              <tr key={g.id} style={{ borderBottom: "1px solid #eee" }}>
                <td style={{ padding: 8 }}>#{g.id}</td>
                <td style={{ padding: 8 }}>{g.languages}</td>
                <td style={{ padding: 8 }}>{g.region}</td>
                <td style={{ padding: 8 }}>{g.rating?.toFixed(1) ?? "—"}</td>
                <td style={{ padding: 8 }}>
                  <button
                    onClick={() => handleToggleAvailability(g)}
                    style={{ background: g.isAvailable ? "#2e7d32" : "#999", color: "#fff", border: "none", padding: "4px 10px" }}
                  >
                    {g.isAvailable ? "Available" : "Unavailable"}
                  </button>
                </td>
                <td style={{ padding: 8 }}>
                  <button onClick={() => handleDelete(g.id)} style={{ color: "red" }}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}