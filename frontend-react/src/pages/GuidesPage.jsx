import { useState, useEffect } from "react";
import api from "../services/api";

export default function GuidesPage() {
  const [guides, setGuides] = useState([]);
  const [loading, setLoading] = useState(true);
  const [regionFilter, setRegionFilter] = useState("");
  const [search, setSearch] = useState("");
  const [availableFilter, setAvailableFilter] = useState("");

  // Add-guide form state
  const [showAddForm, setShowAddForm] = useState(false);
  const [guideUsers, setGuideUsers] = useState([]); // Users with role=Guide
  const [selectedUserId, setSelectedUserId] = useState("");
  const [newLanguages, setNewLanguages] = useState("");
  const [newRegion, setNewRegion] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [createError, setCreateError] = useState(null);

  const fetchGuides = async () => {
    setLoading(true);
    try {
      const params = { pageSize: 50 };
      if (regionFilter) params.region = regionFilter;
      if (search) params.search = search;
      if (availableFilter) params.available = availableFilter;
      const res = await api.get("/guides", { params });
      setGuides(res.data.items);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchGuideUsers = async () => {
    try {
      const res = await api.get("/users", { params: { role: "Guide" } });
      setGuideUsers(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchGuides();
    fetchGuideUsers();
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
      fetchGuideUsers();
    } catch (err) {
      alert("Failed to delete.");
    }
  };

  const handleCreateGuide = async (e) => {
    e.preventDefault();
    if (!selectedUserId || !newRegion.trim()) {
      setCreateError("Please pick a user and enter a region.");
      return;
    }
    setIsCreating(true);
    setCreateError(null);
    try {
      await api.post("/guides", {
        userId: Number(selectedUserId),
        languages: newLanguages.trim() || null,
        region: newRegion.trim(),
        isAvailable: true,
      });
      setSelectedUserId("");
      setNewLanguages("");
      setNewRegion("");
      setShowAddForm(false);
      fetchGuides();
      fetchGuideUsers();
    } catch (err) {
      setCreateError(err.response?.data?.message || "Failed to create guide profile.");
    } finally {
      setIsCreating(false);
    }
  };

  // Only offer Guide-role users who don't already have a linked Guide profile.
  const unlinkedGuideUsers = guideUsers.filter((u) => !u.hasGuideProfile);

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h2>Guides</h2>
        <button
          onClick={() => setShowAddForm((s) => !s)}
          style={{ padding: "8px 16px", background: "#00897b", color: "#fff", border: "none", borderRadius: 4 }}
        >
          {showAddForm ? "Cancel" : "+ Add Guide Profile"}
        </button>
      </div>

      {showAddForm && (
        <form
          onSubmit={handleCreateGuide}
          style={{
            background: "#f5f5f5",
            borderRadius: 8,
            padding: 16,
            marginTop: 12,
            marginBottom: 16,
            display: "flex",
            flexWrap: "wrap",
            gap: 10,
            alignItems: "flex-end",
          }}
        >
          <div>
            <label style={{ display: "block", fontSize: 12, color: "#666", marginBottom: 4 }}>
              User account (role = Guide)
            </label>
            <select
              value={selectedUserId}
              onChange={(e) => setSelectedUserId(e.target.value)}
              style={{ padding: 8, minWidth: 220 }}
            >
              <option value="">Select a user...</option>
              {unlinkedGuideUsers.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.name} ({u.email})
                </option>
              ))}
            </select>
            {guideUsers.length > 0 && unlinkedGuideUsers.length === 0 && (
              <div style={{ fontSize: 11, color: "#999", marginTop: 2 }}>
                Every Guide-role account already has a linked profile.
              </div>
            )}
            {guideUsers.length === 0 && (
              <div style={{ fontSize: 11, color: "#999", marginTop: 2 }}>
                No accounts with role "Guide" have registered yet.
              </div>
            )}
          </div>
          <div>
            <label style={{ display: "block", fontSize: 12, color: "#666", marginBottom: 4 }}>Region</label>
            <input
              placeholder="e.g. Kandy"
              value={newRegion}
              onChange={(e) => setNewRegion(e.target.value)}
              style={{ padding: 8 }}
            />
          </div>
          <div>
            <label style={{ display: "block", fontSize: 12, color: "#666", marginBottom: 4 }}>
              Languages (optional)
            </label>
            <input
              placeholder="e.g. English, Sinhala"
              value={newLanguages}
              onChange={(e) => setNewLanguages(e.target.value)}
              style={{ padding: 8 }}
            />
          </div>
          <button
            type="submit"
            disabled={isCreating}
            style={{ padding: "8px 16px", background: "#1565c0", color: "#fff", border: "none", borderRadius: 4 }}
          >
            {isCreating ? "Creating..." : "Create Profile"}
          </button>
          {createError && <div style={{ color: "#c62828", fontSize: 13, width: "100%" }}>{createError}</div>}
        </form>
      )}

      <div style={{ marginBottom: 16, display: "flex", gap: 8, flexWrap: "wrap" }}>
        <input
          placeholder="Search by language or region..."
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
        <select value={availableFilter} onChange={(e) => setAvailableFilter(e.target.value)} style={{ padding: 8 }}>
          <option value="">Any availability</option>
          <option value="true">Available only</option>
          <option value="false">Unavailable only</option>
        </select>
        <button onClick={fetchGuides} style={{ padding: "8px 16px" }}>Filter</button>
      </div>

      {loading ? (
        <p>Loading...</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr style={{ borderBottom: "2px solid #ccc", textAlign: "left" }}>
              <th style={{ padding: 8 }}>ID</th>
              <th style={{ padding: 8 }}>Name</th>
              <th style={{ padding: 8 }}>Country</th>
              <th style={{ padding: 8 }}>Phone</th>
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
                <td style={{ padding: 8 }}>{g.name ?? "—"}</td>
                <td style={{ padding: 8 }}>{g.country ?? "—"}</td>
                <td style={{ padding: 8 }}>{g.mobileNumber ?? "—"}</td>
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
