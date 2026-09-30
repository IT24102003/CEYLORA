import { useState, useEffect } from "react";
import api, { getWeather } from "../services/api";

export default function DestinationsPage() {
  const [destinations, setDestinations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({
    name: "", region: "", description: "", category: "", imageUrl: "", latitude: "", longitude: "",
  });
  const [search, setSearch] = useState("");
  const [regionFilter, setRegionFilter] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("");

  const fetchDestinations = async () => {
    setLoading(true);
    try {
      const params = { search, pageSize: 50 };
      if (regionFilter) params.region = regionFilter;
      if (categoryFilter) params.category = categoryFilter;
      const res = await api.get("/destinations", { params });
      setDestinations(res.data.items);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDestinations();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const resetForm = () => {
    setForm({ name: "", region: "", description: "", category: "", imageUrl: "", latitude: "", longitude: "" });
    setEditingId(null);
    setShowForm(false);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      latitude: form.latitude === "" ? null : parseFloat(form.latitude),
      longitude: form.longitude === "" ? null : parseFloat(form.longitude),
    };
    try {
      if (editingId) {
        await api.put(`/destinations/${editingId}`, payload);
      } else {
        await api.post("/destinations", payload);
      }
      resetForm();
      fetchDestinations();
    } catch (err) {
      alert(err.response?.data?.message || "Failed to save destination.");
    }
  };

  const [weatherData, setWeatherData] = useState({});

  const fetchWeather = async (dest) => {
  if (!dest.latitude || !dest.longitude) return;
  try {
    const res = await getWeather(dest.latitude, dest.longitude);
    setWeatherData((prev) => ({ ...prev, [dest.id]: res.data }));
  } catch (err) {
    console.error("Weather fetch failed", err);
  }
};

  const handleEdit = (dest) => {
    setForm({
      name: dest.name, region: dest.region, description: dest.description || "",
      category: dest.category || "", imageUrl: dest.imageUrl || "",
      latitude: dest.latitude ?? "", longitude: dest.longitude ?? "",
    });
    setEditingId(dest.id);
    setShowForm(true);
  };

  const handleDelete = async (id) => {
    if (!confirm("Delete this destination?")) return;
    try {
      await api.delete(`/destinations/${id}`);
      fetchDestinations();
    } catch (err) {
      alert("Failed to delete.");
    }
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Destinations</h2>

      <div style={{ marginBottom: 16, display: "flex", gap: 8 }}>
        <input
          placeholder="Search destinations..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ padding: 8, flex: 1 }}
        />
        <input
          placeholder="Filter by region..."
          value={regionFilter}
          onChange={(e) => setRegionFilter(e.target.value)}
          style={{ padding: 8, width: 160 }}
        />
        <input
          placeholder="Filter by category..."
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value)}
          style={{ padding: 8, width: 160 }}
        />
        <button onClick={fetchDestinations} style={{ padding: "8px 16px" }}>Search</button>
        <button onClick={() => { resetForm(); setShowForm(true); }} style={{ padding: "8px 16px", background: "#1565c0", color: "#fff", border: "none" }}>
          + Add Destination
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} style={{ border: "1px solid #ccc", padding: 16, marginBottom: 20, borderRadius: 8 }}>
          <h3>{editingId ? "Edit" : "Add"} Destination</h3>
          <input placeholder="Name" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input placeholder="Region" required value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input placeholder="Category" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <textarea placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input placeholder="Image URL" value={form.imageUrl} onChange={(e) => setForm({ ...form, imageUrl: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          {form.imageUrl && (
            <img
              src={form.imageUrl}
              alt="Preview"
              style={{ width: 120, height: 80, objectFit: "cover", borderRadius: 6, marginBottom: 8, display: "block" }}
              onError={(e) => { e.target.style.display = "none"; }}
            />
          )}
          <div style={{ display: "flex", gap: 8, marginBottom: 8 }}>
            <input
              type="number" step="any" placeholder="Latitude"
              value={form.latitude} onChange={(e) => setForm({ ...form, latitude: e.target.value })}
              style={{ flex: 1, padding: 8 }}
            />
            <input
              type="number" step="any" placeholder="Longitude"
              value={form.longitude} onChange={(e) => setForm({ ...form, longitude: e.target.value })}
              style={{ flex: 1, padding: 8 }}
            />
          </div>
          <button type="submit" style={{ padding: "8px 16px", marginRight: 8 }}>Save</button>
          <button type="button" onClick={resetForm} style={{ padding: "8px 16px" }}>Cancel</button>
        </form>
      )}

      {loading ? (
        <p>Loading...</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr style={{ borderBottom: "2px solid #ccc", textAlign: "left" }}>
              <th style={{ padding: 8 }}>Photo</th>
              <th style={{ padding: 8 }}>Name</th>
              <th style={{ padding: 8 }}>Region</th>
              <th style={{ padding: 8 }}>Category</th>
              <th style={{ padding: 8 }}>Coordinates</th>
              <th style={{ padding: 8 }}>Weather</th>
              <th style={{ padding: 8 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {destinations.map((d) => (
              <tr key={d.id} style={{ borderBottom: "1px solid #eee" }}>
                <td style={{ padding: 8 }}>
                  {d.imageUrl ? (
                    <img src={d.imageUrl} alt={d.name} style={{ width: 64, height: 48, objectFit: "cover", borderRadius: 4 }} />
                  ) : (
                    <div style={{ width: 64, height: 48, background: "#eee", borderRadius: 4, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, color: "#999" }}>
                      No photo
                    </div>
                  )}
                </td>
                <td style={{ padding: 8 }}>{d.name}</td>
                <td style={{ padding: 8 }}>{d.region}</td>
                <td style={{ padding: 8 }}>{d.category}</td>
                <td style={{ padding: 8, fontSize: 12, color: "#666" }}>
                  {d.latitude != null && d.longitude != null ? `${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}` : "—"}
                </td>
                <td style={{ padding: 8 }}>
                    {weatherData[d.id] ? (
                        weatherData[d.id].available ? (
                            <span>
                                {weatherData[d.id].temperature}°C {weatherData[d.id].isRainy ? "🌧️" : "☀️"}
                            </span>
                        ) : (
                            <span style={{ color: "#999" }}>N/A</span>
                        )
                    ) : (
                        <button onClick={() => fetchWeather(d)} style={{ fontSize: 12, padding: "2px 8px" }}>
                            Check
                        </button>
                    )}
                </td>
                <td style={{ padding: 8 }}>
                  <button onClick={() => handleEdit(d)} style={{ marginRight: 8 }}>Edit</button>
                  <button onClick={() => handleDelete(d.id)} style={{ color: "red" }}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}