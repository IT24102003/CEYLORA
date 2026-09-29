import { useState, useEffect } from "react";
import api from "../services/api";

export default function PackagesPage() {
  const [packages, setPackages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({
    name: "", description: "", basePrice: "", durationDays: "", isPublished: false,
  });

  const fetchPackages = async () => {
    setLoading(true);
    try {
      const res = await api.get("/packages", { params: { pageSize: 50 } });
      setPackages(res.data.items);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPackages();
  }, []);

  const resetForm = () => {
    setForm({ name: "", description: "", basePrice: "", durationDays: "", isPublished: false });
    setEditingId(null);
    setShowForm(false);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      basePrice: parseFloat(form.basePrice),
      durationDays: parseInt(form.durationDays),
    };
    try {
      if (editingId) {
        await api.put(`/packages/${editingId}`, payload);
      } else {
        await api.post("/packages", payload);
      }
      resetForm();
      fetchPackages();
    } catch (err) {
      alert(err.response?.data?.message || "Failed to save package.");
    }
  };

  const handleEdit = (pkg) => {
    setForm({
      name: pkg.name, description: pkg.description || "",
      basePrice: pkg.basePrice, durationDays: pkg.durationDays, isPublished: pkg.isPublished,
    });
    setEditingId(pkg.id);
    setShowForm(true);
  };

  const handleDelete = async (id) => {
    if (!confirm("Delete this package?")) return;
    try {
      await api.delete(`/packages/${id}`);
      fetchPackages();
    } catch (err) {
      alert("Failed to delete.");
    }
  };

  const handleTogglePublish = async (pkg) => {
    try {
      await api.put(`/packages/${pkg.id}`, { ...pkg, isPublished: !pkg.isPublished });
      fetchPackages();
    } catch (err) {
      alert("Failed to update publish status.");
    }
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Packages</h2>

      <button onClick={() => { resetForm(); setShowForm(true); }} style={{ padding: "8px 16px", background: "#1565c0", color: "#fff", border: "none", marginBottom: 16 }}>
        + Add Package
      </button>

      {showForm && (
        <form onSubmit={handleSubmit} style={{ border: "1px solid #ccc", padding: 16, marginBottom: 20, borderRadius: 8 }}>
          <h3>{editingId ? "Edit" : "Add"} Package</h3>
          <input placeholder="Name" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <textarea placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input type="number" placeholder="Base Price (LKR)" required value={form.basePrice} onChange={(e) => setForm({ ...form, basePrice: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <input type="number" placeholder="Duration (days)" required value={form.durationDays} onChange={(e) => setForm({ ...form, durationDays: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8 }} />
          <label style={{ display: "block", marginBottom: 8 }}>
            <input type="checkbox" checked={form.isPublished} onChange={(e) => setForm({ ...form, isPublished: e.target.checked })} /> Published
          </label>
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
              <th style={{ padding: 8 }}>Price (LKR)</th>
              <th style={{ padding: 8 }}>Duration</th>
              <th style={{ padding: 8 }}>Published</th>
              <th style={{ padding: 8 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {packages.map((p) => (
              <tr key={p.id} style={{ borderBottom: "1px solid #eee" }}>
                <td style={{ padding: 8 }}>{p.name}</td>
                <td style={{ padding: 8 }}>{p.basePrice}</td>
                <td style={{ padding: 8 }}>{p.durationDays} days</td>
                <td style={{ padding: 8 }}>
                  <button onClick={() => handleTogglePublish(p)} style={{ background: p.isPublished ? "#2e7d32" : "#999", color: "#fff", border: "none", padding: "4px 10px" }}>
                    {p.isPublished ? "Published" : "Draft"}
                  </button>
                </td>
                <td style={{ padding: 8 }}>
                  <button onClick={() => handleEdit(p)} style={{ marginRight: 8 }}>Edit</button>
                  <button onClick={() => handleDelete(p.id)} style={{ color: "red" }}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}