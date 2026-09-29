import { useAuth } from "../context/AuthContext";
import { Link } from "react-router-dom";

export default function DashboardPage() {
  const { user, logout } = useAuth();

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Welcome, {user?.name}</h2>
      <p>Role: {user?.role}</p>
      <Link to="/agent-monitor" style={{ marginLeft: 10 }}>Agent Workflow Monitor</Link>
      <Link to="/destinations" style={{ marginLeft: 10 }}>Destinations</Link>
      <Link to="/packages" style={{ marginLeft: 10 }}>Packages</Link>
      <Link to="/hotels" style={{ marginLeft: 10 }}>Hotels</Link>
      <Link to="/bookings" style={{ marginLeft: 10 }}>Bookings</Link>
      <Link to="/guides" style={{ marginLeft: 10 }}>Guides</Link>
      <Link to="/vehicles" style={{ marginLeft: 10 }}>Vehicles</Link>
      <button onClick={logout}>Logout</button>
    </div>
  );
}