import { useState, useEffect, Fragment } from "react";
import api from "../services/api";

export default function PackagesPage() {
  const [packages, setPackages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({
    name: "", description: "", basePrice: "", durationDays: "", maxPeople: "4", isPublished: false,
  });

  // For the destinations/hotel pickers inside the expanded "Manage Trip Details" panel.
  // (No guide/vehicle picker here — a package no longer pre-assigns a guide/vehicle.
  // That's decided per-booking instead, by the admin from the Bookings page's Pending
  // tab, once a tourist has actually bought the package and paid.)
  const [allDestinations, setAllDestinations] = useState([]);
  const [allHotels, setAllHotels] = useState([]);

  const [expandedId, setExpandedId] = useState(null);
  const [newDestId, setNewDestId] = useState("");
  const [newDestDay, setNewDestDay] = useState("1");
  const [newHotelId, setNewHotelId] = useState("");

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

  const fetchPickerData = async () => {
    try {
      const [destRes, hotelRes] = await Promise.all([
        api.get("/destinations", { params: { pageSize: 200 } }),
        api.get("/hotels", { params: { pageSize: 200 } }),
      ]);
      setAllDestinations(destRes.data.items ?? []);
      setAllHotels(hotelRes.data.items ?? []);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchPackages();
    fetchPickerData();
  }, []);

  const resetForm = () => {
    setForm({ name: "", description: "", basePrice: "", durationDays: "", maxPeople: "4", isPublished: false });
    setEditingId(null);
    setShowForm(false);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      basePrice: parseFloat(form.basePrice),
      durationDays: parseInt(form.durationDays),
      maxPeople: parseInt(form.maxPeople) || 4,
      suggestedGuideId: null,
      suggestedVehicleId: null,
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
      basePrice: pkg.basePrice, durationDays: pkg.durationDays,
      maxPeople: pkg.maxPeople ?? 4,
      isPublished: pkg.isPublished,
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
      await api.put(`/packages/${pkg.id}`, {
        name: pkg.name, description: pkg.description, basePrice: pkg.basePrice,
        durationDays: pkg.durationDays, maxPeople: pkg.maxPeople,
        suggestedGuideId: null, suggestedVehicleId: null,
        isPublished: !pkg.isPublished,
      });
      fetchPackages();
    } catch (err) {
      alert("Failed to update publish status.");
    }
  };

  // Adding a destination is all it takes to extend the route — the backend returns the
  // destinations in DayNumber order with coordinates, so there's nothing else to "build".
  const addDestination = async (pkgId) => {
    if (!newDestId) return;
    try {
      await api.post(`/packages/${pkgId}/destinations`, {
        destinationId: Number(newDestId),
        dayNumber: parseInt(newDestDay) || 1,
      });
      setNewDestId("");
      setNewDestDay("1");
      fetchPackages();
    } catch (err) {
      alert(err.response?.data?.message || "Failed to add destination.");
    }
  };

  const removeDestination = async (pkgId, packageDestinationId) => {
    try {
      await api.delete(`/packages/${pkgId}/destinations/${packageDestinationId}`);
      fetchPackages();
    } catch (err) {
      alert("Failed to remove destination.");
    }
  };

  const addHotel = async (pkgId) => {
    if (!newHotelId) return;
    try {
      await api.post(`/packages/${pkgId}/hotels`, { hotelId: Number(newHotelId) });
      setNewHotelId("");
      fetchPackages();
    } catch (err) {
      alert(err.response?.data?.message || "Failed to add hotel.");
    }
  };

  const removeHotel = async (pkgId, packageHotelId) => {
    try {
      await api.delete(`/packages/${pkgId}/hotels/${packageHotelId}`);
      fetchPackages();
    } catch (err) {
      alert("Failed to remove hotel.");
    }
  };

  // Builds a Google Maps directions link from the package's destinations (already ordered
  // by DayNumber from the backend) and opens it in a new tab.
  const viewRoute = (pkg) => {
    const points = (pkg.destinations ?? []).filter((d) => d.latitude != null && d.longitude != null);
    if (points.length === 0) {
      alert("This package has no destinations with coordinates yet.");
      return;
    }
    const origin = `${points[0].latitude},${points[0].longitude}`;
    const destination = `${points[points.length - 1].latitude},${points[points.length - 1].longitude}`;
    const waypoints = points.length > 2
      ? points.slice(1, -1).map((p) => `${p.latitude},${p.longitude}`).join("|")
      : "";
    const url = `https://www.google.com/maps/dir/?api=1&origin=${origin}&destination=${destination}` +
      (waypoints ? `&waypoints=${waypoints}` : "") + "&travelmode=driving";
    window.open(url, "_blank");
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Packages</h2>

      <button onClick={() => { resetForm(); setShowForm(true); }} style={{ padding: "8px 16px", background: "#1565c0", color: "#fff", border: "none", marginBottom: 16 }}>
        + Add Package
      </button>

      {showForm && (
        <form onSubmit={handleSubmit} style={{ border: "1px solid #ccc", padding: 16, marginBottom: 20, borderRadius: 8, maxWidth: 640 }}>
          <h3 style={{ marginTop: 0 }}>{editingId ? "Edit" : "Add"} Package</h3>
          <input placeholder="Name" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8, boxSizing: "border-box" }} />
          <textarea placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} style={{ display: "block", width: "100%", padding: 8, marginBottom: 8, boxSizing: "border-box" }} />

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8, marginBottom: 8 }}>
            <input type="number" placeholder="Base Price (LKR)" required value={form.basePrice} onChange={(e) => setForm({ ...form, basePrice: e.target.value })} style={{ padding: 8 }} />
            <input type="number" placeholder="Duration (days)" required value={form.durationDays} onChange={(e) => setForm({ ...form, durationDays: e.target.value })} style={{ padding: 8 }} />
            <input type="number" placeholder="Max People" required value={form.maxPeople} onChange={(e) => setForm({ ...form, maxPeople: e.target.value })} style={{ padding: 8 }} />
          </div>

          <p style={{ fontSize: 12.5, color: "#888", marginTop: 0, marginBottom: 8 }}>
            A guide &amp; vehicle are no longer pre-assigned to the package itself — once a
            tourist buys this package and pays, assign a guide &amp; vehicle to that specific
            booking from the Bookings page's Pending tab.
          </p>

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
              <th style={{ padding: 8 }}>Max People</th>
              <th style={{ padding: 8 }}>Destinations</th>
              <th style={{ padding: 8 }}>Published</th>
              <th style={{ padding: 8 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {packages.map((p) => (
              <Fragment key={p.id}>
                <tr style={{ borderBottom: "1px solid #eee" }}>
                  <td style={{ padding: 8 }}>{p.name}</td>
                  <td style={{ padding: 8 }}>{p.basePrice}</td>
                  <td style={{ padding: 8 }}>{p.durationDays} days</td>
                  <td style={{ padding: 8 }}>{p.maxPeople}</td>
                  <td style={{ padding: 8 }}>{p.destinations?.length ?? 0}</td>
                  <td style={{ padding: 8 }}>
                    <button onClick={() => handleTogglePublish(p)} style={{ background: p.isPublished ? "#2e7d32" : "#999", color: "#fff", border: "none", padding: "4px 10px" }}>
                      {p.isPublished ? "Published" : "Draft"}
                    </button>
                  </td>
                  <td style={{ padding: 8, whiteSpace: "nowrap" }}>
                    <button onClick={() => setExpandedId(expandedId === p.id ? null : p.id)} style={{ marginRight: 8 }}>
                      {expandedId === p.id ? "Hide" : "Manage"}
                    </button>
                    <button onClick={() => viewRoute(p)} style={{ marginRight: 8 }}>View Route</button>
                    <button onClick={() => handleEdit(p)} style={{ marginRight: 8 }}>Edit</button>
                    <button onClick={() => handleDelete(p.id)} style={{ color: "red" }}>Delete</button>
                  </td>
                </tr>
                {expandedId === p.id && (
                  <tr>
                    <td colSpan={7} style={{ padding: 16, background: "#f7f8fa" }}>
                      <div style={{ display: "flex", gap: 24, flexWrap: "wrap" }}>
                        <div style={{ flex: "1 1 300px" }}>
                          <h4 style={{ marginTop: 0 }}>Destinations &amp; Route</h4>
                          {p.destinations?.length ? (
                            <ol style={{ paddingLeft: 18 }}>
                              {p.destinations.map((d) => (
                                <li key={d.id} style={{ marginBottom: 4 }}>
                                  Day {d.dayNumber}: {d.name} ({d.region})
                                  <button onClick={() => removeDestination(p.id, d.id)} style={{ marginLeft: 8, color: "red", fontSize: 12 }}>
                                    Remove
                                  </button>
                                </li>
                              ))}
                            </ol>
                          ) : (
                            <p style={{ color: "#888", fontSize: 13 }}>No destinations added yet.</p>
                          )}
                          <div style={{ display: "flex", gap: 6 }}>
                            <select value={newDestId} onChange={(e) => setNewDestId(e.target.value)} style={{ flex: 1, padding: 6 }}>
                              <option value="">Select destination...</option>
                              {allDestinations.map((d) => (
                                <option key={d.id} value={d.id}>{d.name} ({d.region})</option>
                              ))}
                            </select>
                            <input
                              type="number" min="1" value={newDestDay} onChange={(e) => setNewDestDay(e.target.value)}
                              style={{ width: 70, padding: 6 }} title="Day number"
                            />
                            <button onClick={() => addDestination(p.id)}>Add</button>
                          </div>
                        </div>

                        <div style={{ flex: "1 1 260px" }}>
                          <h4 style={{ marginTop: 0 }}>Hotels</h4>
                          {p.hotels?.length ? (
                            <ul style={{ paddingLeft: 18 }}>
                              {p.hotels.map((h) => (
                                <li key={h.id} style={{ marginBottom: 4 }}>
                                  {h.name} ({h.region}) — LKR {h.pricePerNight}/night
                                  <button onClick={() => removeHotel(p.id, h.id)} style={{ marginLeft: 8, color: "red", fontSize: 12 }}>
                                    Remove
                                  </button>
                                </li>
                              ))}
                            </ul>
                          ) : (
                            <p style={{ color: "#888", fontSize: 13 }}>No hotels added yet.</p>
                          )}
                          <div style={{ display: "flex", gap: 6 }}>
                            <select value={newHotelId} onChange={(e) => setNewHotelId(e.target.value)} style={{ flex: 1, padding: 6 }}>
                              <option value="">Select hotel...</option>
                              {allHotels.map((h) => (
                                <option key={h.id} value={h.id}>{h.name} ({h.region})</option>
                              ))}
                            </select>
                            <button onClick={() => addHotel(p.id)}>Add</button>
                          </div>
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
