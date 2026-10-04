import { useState, useEffect } from "react";
import api from "../services/api";

export default function HotelsPage() {
  const [hotels, setHotels] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({
    name: "", region: "", address: "", latitude: "", longitude: "", starRating: "", pricePerNight: "",
    roomsAvailable: "", description: "", imageUrl: "",
  });
  const [search, setSearch] = useState("");
  const [regionFilter, setRegionFilter] = useState("");
  const [minStars, setMinStars] = useState("");

  const fetchHotels = async () => {
    setLoading(true);
    try {
      const params = { pageSize: 50 };
      if (search) params.search = search;
      if (regionFilter) params.region = regionFilter;
      if (minStars) params.minStars = minStars;
      const res = await api.get("/hotels", { params });
      setHotels(res.data.items);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHotels();
  }, []);

  const resetForm = () => {
    setForm({ name: "", region: "", address: "", latitude: "", longitude: "", starRating: "", pricePerNight: "", roomsAvailable: "", description: "", imageUrl: "" });
    setEditingId(null);
    setShowForm(false);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      // 🔥 Optional — lets this hotel be included in the AI trip planner's
      // route/km calculation alongside destinations. Left blank = skipped.
      latitude: form.latitude === "" ? null : parseFloat(form.latitude),
      longitude: form.longitude === "" ? null : parseFloat(form.longitude),
      starRating: parseInt(form.starRating),
      pricePerNight: parseFloat(form.pricePerNight),
      roomsAvailable: parseInt(form.roomsAvailable),
    };
    try {
      if (editingId) {
        await api.put(`/hotels/${editingId}`, payload);
      } else {
        await api.post("/hotels", payload);
      }
      resetForm();
      fetchHotels();
    } catch (err) {
      alert(err.response?.data?.message || "Failed to save hotel.");
    }
  };

  const handleEdit = (hotel) => {
    setForm({
      name: hotel.name, region: hotel.region, address: hotel.address || "",
      latitude: hotel.latitude ?? "", longitude: hotel.longitude ?? "",
      starRating: hotel.starRating, pricePerNight: hotel.pricePerNight,
      roomsAvailable: hotel.roomsAvailable, description: hotel.description || "",
      imageUrl: hotel.imageUrl || "",
    });
    setEditingId(hotel.id);
    setShowForm(true);
  };

  const handleDelete = async (id) => {
    if (!confirm("Delete this hotel?")) return;
    try {
      await api.delete(`/hotels/${id}`);
      fetchHotels();
    } catch (err) {
      alert("Failed to delete.");
    }
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Hotels</h2>

      <div style={{ marginBottom: 16, display: "flex", gap: 8, flexWrap: "wrap" }}>
        <input
          placeholder="Search hotels..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ padding: 8, flex: 1, minWidth: 160 }}
        />
        <input
          placeholder="Filter by region..."
          value={regionFilter}
          onChange={(e) => setRegionFilter(e.target.value)}
          style={{ padding: 8, width: 160 }}
        />
        <select value={minStars} onChange={(e) => setMinStars(e.target.value)} style={{ padding: 8 }}>
          <option value="">Any star rating</option>
          <option value="1">1★ and up</option>
          <option value="2">2★ and up</option>
          <option value="3">3★ and up</option>
          <option value="4">4★ and up</option>
          <option value="5">5★ only</option>
        </select>
        <button onClick={fetchHotels} style={{ padding: "8px 16px" }}>Search</button>
        <button onClick={() => { resetForm(); setShowForm(true); }} style={{ padding: "8px 16px", background: "#1565c0", color: "#fff", border: "none" }}>
          + Add Hotel
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} style={{ border: "1px solid #ccc", padding: 16, marginBottom: 20, borderRadius: 8, maxWidth: 640 }}>
          <h3 style={{ marginTop: 0 }}>{editingId ? "Edit" : "Add"} Hotel</h3>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginBottom: 8 }}>
            <input placeholder="Name" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} style={{ padding: 8 }} />
            <input placeholder="Region" required value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} style={{ padding: 8 }} />
          </div>

          <input placeholder="Address" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8, boxSizing: "border-box" }} />

          {/* 🔥 Optional — without these, this hotel is skipped by the AI trip planner's
              route/km calculation (it only has an address, no coordinates). Look the hotel
              up on Google Maps, right-click the pin, and the lat/long is the first thing
              in the popup. */}
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginBottom: 8 }}>
            <input type="number" step="any" placeholder="Latitude (optional, for route/km)" value={form.latitude} onChange={(e) => setForm({ ...form, latitude: e.target.value })} style={{ padding: 8 }} />
            <input type="number" step="any" placeholder="Longitude (optional, for route/km)" value={form.longitude} onChange={(e) => setForm({ ...form, longitude: e.target.value })} style={{ padding: 8 }} />
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8, marginBottom: 8 }}>
            <input type="number" min="1" max="5" placeholder="Star Rating (1-5)" required value={form.starRating} onChange={(e) => setForm({ ...form, starRating: e.target.value })} style={{ padding: 8 }} />
            <input type="number" placeholder="Price/Night (LKR)" required value={form.pricePerNight} onChange={(e) => setForm({ ...form, pricePerNight: e.target.value })} style={{ padding: 8 }} />
            <input type="number" placeholder="Rooms Available" required value={form.roomsAvailable} onChange={(e) => setForm({ ...form, roomsAvailable: e.target.value })} style={{ padding: 8 }} />
          </div>

          <input placeholder="Image URL" value={form.imageUrl} onChange={(e) => setForm({ ...form, imageUrl: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8, boxSizing: "border-box" }} />
          {form.imageUrl && (
            <img
              src={form.imageUrl}
              alt="Preview"
              style={{ width: 160, height: 100, objectFit: "cover", borderRadius: 6, marginBottom: 8, display: "block" }}
              onError={(e) => { e.target.style.display = "none"; }}
            />
          )}

          <textarea placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8, boxSizing: "border-box" }} />
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
              <th style={{ padding: 8 }}>Stars</th>
              <th style={{ padding: 8 }}>Price/Night</th>
              <th style={{ padding: 8 }}>Rooms</th>
              <th style={{ padding: 8 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {hotels.map((h) => (
              <tr key={h.id} style={{ borderBottom: "1px solid #eee" }}>
                <td style={{ padding: 8 }}>
                  {h.imageUrl ? (
                    <img src={h.imageUrl} alt={h.name} style={{ width: 64, height: 48, objectFit: "cover", borderRadius: 4 }} />
                  ) : (
                    <div style={{ width: 64, height: 48, background: "#eee", borderRadius: 4, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, color: "#999" }}>
                      No photo
                    </div>
                  )}
                </td>
                <td style={{ padding: 8 }}>{h.name}</td>
                <td style={{ padding: 8 }}>{h.region}</td>
                <td style={{ padding: 8 }}>{"★".repeat(h.starRating)}</td>
                <td style={{ padding: 8 }}>{h.pricePerNight}</td>
                <td style={{ padding: 8 }}>{h.roomsAvailable}</td>
                <td style={{ padding: 8 }}>
                  <button onClick={() => handleEdit(h)} style={{ marginRight: 8 }}>Edit</button>
                  <button onClick={() => handleDelete(h.id)} style={{ color: "red" }}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}