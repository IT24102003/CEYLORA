import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

// Left sidebar nav shared by every admin page (replaces the old row of text links that
// used to live at the top of DashboardPage). Each page keeps rendering its own content —
// this just wraps it with a persistent left-side nav + a logout button.
const NAV_ITEMS = [
  { to: "/analytics", label: "Analytics", icon: "📊" },
  { to: "/agent-monitor", label: "Agent Workflow Monitor", icon: "🤖" },
  { to: "/bookings", label: "Bookings", icon: "🧾" },
  { to: "/destinations", label: "Destinations", icon: "📍" },
  { to: "/packages", label: "Packages", icon: "🎒" },
  { to: "/hotels", label: "Hotels", icon: "🏨" },
  { to: "/guides", label: "Guides", icon: "🧭" },
  { to: "/vehicles", label: "Vehicles", icon: "🚐" },
  { to: "/reviews", label: "Reviews", icon: "⭐" },
  { to: "/verifications", label: "Verifications", icon: "✅" },
];

export default function AdminLayout() {
  const { user, logout } = useAuth();

  return (
    <div style={{ display: "flex", minHeight: "100vh", fontFamily: "sans-serif" }}>
      <aside
        style={{
          width: 230,
          flexShrink: 0,
          background: "#1a2233",
          color: "#fff",
          display: "flex",
          flexDirection: "column",
          position: "sticky",
          top: 0,
          height: "100vh",
        }}
      >
        <div style={{ padding: "20px 18px", borderBottom: "1px solid #2c3750" }}>
          <div style={{ fontWeight: 700, fontSize: 18 }}>CEYLORA</div>
          <div style={{ fontSize: 12, color: "#9aa5bd" }}>Admin Panel</div>
        </div>

        <nav style={{ flex: 1, overflowY: "auto", padding: "10px 0" }}>
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              style={({ isActive }) => ({
                display: "flex",
                alignItems: "center",
                gap: 10,
                padding: "10px 18px",
                color: isActive ? "#fff" : "#b7c0d8",
                background: isActive ? "#2b62d9" : "transparent",
                textDecoration: "none",
                fontSize: 14,
                fontWeight: isActive ? 600 : 400,
                borderRadius: isActive ? "0 20px 20px 0" : 0,
                marginRight: isActive ? 12 : 0,
              })}
            >
              <span style={{ fontSize: 16 }}>{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div style={{ padding: 16, borderTop: "1px solid #2c3750" }}>
          <div style={{ fontSize: 13, color: "#9aa5bd", marginBottom: 8 }}>
            {user?.name} ({user?.role})
          </div>
          <button
            onClick={logout}
            style={{
              width: "100%",
              padding: "8px 0",
              background: "#2c3750",
              color: "#fff",
              border: "none",
              borderRadius: 6,
              cursor: "pointer",
            }}
          >
            Logout
          </button>
        </div>
      </aside>

      <main style={{ flex: 1, minWidth: 0, background: "#f7f8fa" }}>
        <Outlet />
      </main>
    </div>
  );
}
