import { useState, useEffect } from "react";
import api from "../services/api";

export default function VehiclesPage() {
  const [vehicles, setVehicles] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchVehicles = async () => {
    setLoading(true);
    try {
      const res = await api.get("/vehicles", { params: { pageSize: 50 } });
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

      {loading ? (
        <p>Loading...</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr style={{ borderBottom: "2px solid #ccc", textAlign: "left" }}>
              <th style={{ padding: 8 }}>ID</th>
              <th style={{ padding: 8 }}>Type</th>
              <th style={{ padding: 8 }}>Capacity</th>
              <th style={{ padding: 8 }}>Region</th>
              <th style={{ padding: 8 }}>Available</th>
              <th style={{ padding: 8 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {vehicles.map((v) => (
              <tr key={v.id} style={{ borderBottom: "1px solid #eee" }}>
                <td style={{ padding: 8 }}>#{v.id}</td>
                <td style={{ padding: 8 }}>{v.type}</td>
                <td style={{ padding: 8 }}>{v.capacity}</td>
                <td style={{ padding: 8 }}>{v.region}</td>
                <td style={{ padding: 8 }}>
                  <span style={{ background: v.isAvailable ? "#2e7d32" : "#999", color: "#fff", padding: "3px 10px", borderRadius: 4 }}>
                    {v.isAvailable ? "Available" : "Unavailable"}
                  </span>
                </td>
                <td style={{ padding: 8 }}>
                  <button onClick={() => handleDelete(v.id)} style={{ color: "red" }}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}