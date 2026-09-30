import { useState, useEffect } from "react";
import api from "../services/api";

export default function VehiclesPage() {
  const [vehicles, setVehicles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [regionFilter, setRegionFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState("");
  const [availableFilter, setAvailableFilter] = useState("");

  const fetchVehicles = async () => {
    setLoading(true);
    try {
      const params = { pageSize: 50 };
      if (search) params.search = search;
      if (regionFilter) params.region = regionFilter;
      if (typeFilter) params.type = typeFilter;
      if (availableFilter) params.available = availableFilter;
      const res = await api.get("/vehicles", { params });
      setVehicles(res.data.items);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchVehicles();
  }, []);

  const handleDelete = async (id) => {
    if (!confirm("Delete this vehicle?")) return;
    try {
      await api.delete(`/vehicles/${id}`);
      fetchVehicles();
    } catch (err) {
      alert("Failed to delete.");
    }
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Vehicles</h2>

      <div style={{ marginBottom: 16, display: "flex", gap: 8, flexWrap: "wrap" }}>
        <input
          placeholder="Search by type or region..."
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
        <input
          placeholder="Filter by type..."
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value)}
          style={{ padding: 8, width: 140 }}
        />
        <select value={availableFilter} onChange={(e) => setAvailableFilter(e.target.value)} style={{ padding: 8 }}>
          <option value="">Any availability</option>
          <option value="true">Available only</option>
          <option value="false">Unavailable only</option>
        </select>
        <button onClick={fetchVehicles} style={{ padding: "8px 16px" }}>Search</button>
      </div>

      {loading ? (
        <p>Loading...</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr style={{ borderBottom: "2px solid #ccc", textAlign: "left" }}>
              <th style={{ padding: 8 }}>Photo</th>
              <th style={{ padding: 8 }}>ID</th>
              <th style={{ padding: 8 }}>Name</th>
              <th style={{ padding: 8 }}>Type</th>
              <th style={{ padding: 8 }}>Owner</th>
              <th style={{ padding: 8 }}>Country</th>
              <th style={{ padding: 8 }}>Phone</th>
              <th style={{ padding: 8 }}>Capacity</th>
              <th style={{ padding: 8 }}>Region</th>
              <th style={{ padding: 8 }}>LKR/km</th>
              <th style={{ padding: 8 }}>Available</th>
              <th style={{ padding: 8 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {vehicles.map((v) => {
              const cover = v.images?.find((i) => i.isCover) ?? v.images?.[0];
              return (
              <tr key={v.id} style={{ borderBottom: "1px solid #eee" }}>
                <td style={{ padding: 8 }}>
                  {cover?.imageUrl ? (
                    <img src={cover.imageUrl} alt={v.name ?? v.type} style={{ width: 64, height: 48, objectFit: "cover", borderRadius: 4 }} />
                  ) : (
                    <div style={{ width: 64, height: 48, background: "#eee", borderRadius: 4, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, color: "#999" }}>
                      No photo
                    </div>
                  )}
                </td>
                <td style={{ padding: 8 }}>#{v.id}</td>
                <td style={{ padding: 8 }}>{v.name ?? "—"}</td>
                <td style={{ padding: 8 }}>{v.type}</td>
                <td style={{ padding: 8 }}>{v.ownerName ?? "—"}</td>
                <td style={{ padding: 8 }}>{v.ownerCountry ?? "—"}</td>
                <td style={{ padding: 8 }}>{v.ownerPhone ?? "—"}</td>
                <td style={{ padding: 8 }}>{v.capacity}</td>
                <td style={{ padding: 8 }}>{v.region}</td>
                <td style={{ padding: 8 }}>{v.pricePerKm}</td>
                <td style={{ padding: 8 }}>
                  <span style={{ background: v.isAvailable ? "#2e7d32" : "#999", color: "#fff", padding: "3px 10px", borderRadius: 4 }}>
                    {v.isAvailable ? "Available" : "Unavailable"}
                  </span>
                </td>
                <td style={{ padding: 8 }}>
                  <button onClick={() => handleDelete(v.id)} style={{ color: "red" }}>Delete</button>
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