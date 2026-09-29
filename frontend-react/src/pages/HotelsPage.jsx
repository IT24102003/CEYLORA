import { useState, useEffect } from "react";
import api from "../services/api";

export default function HotelsPage() {
  const [hotels, setHotels] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({
    name: "", region: "", address: "", starRating: "", pricePerNight: "",
    roomsAvailable: "", description: "",
  });

  const fetchHotels = async () => {
    setLoading(true);
    try {
      const res = await api.get("/hotels", { params: { pageSize: 50 } });
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
    setForm({ name: "", region: "", address: "", starRating: "", pricePerNight: "", roomsAvailable: "", description: "" });
    setEditingId(null);
    setShowForm(false);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
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
      starRating: hotel.starRating, pricePerNight: hotel.pricePerNight,
      roomsAvailable: hotel.roomsAvailable, description: hotel.description || "",
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

      <button onClick={() => { resetForm(); setShowForm(true); }} style={{ padding: "8px 16px", background: "#1565c0", color: "#fff", border: "none", marginBottom: 16 }}>
        + Add Hotel
      </button>

      {showForm && (
        <form onSubmit={handleSubmit} style={{ border: "1px solid #ccc", padding: 16, marginBottom: 20, borderRadius: 8 }}>
          <h3>{editingId ? "Edit" : "Add"} Hotel</h3>
          <input placeholder="Name" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input placeholder="Region" required value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input placeholder="Address" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input type="number" min="1" max="5" placeholder="Star Rating (1-5)" required value={form.starRating} onChange={(e) => setForm({ ...form, starRating: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input type="number" placeholder="Price per Night (LKR)" required value={form.pricePerNight} onChange={(e) => setForm({ ...form, pricePerNight: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input type="number" placeholder="Rooms Available" required value={form.roomsAvailable} onChange={(e) => setForm({ ...form, roomsAvailable: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <textarea placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
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