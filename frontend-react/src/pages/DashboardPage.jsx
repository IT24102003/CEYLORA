import { useAuth } from "../context/AuthContext";

export default function DashboardPage() {
  const { user, logout } = useAuth();

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Welcome, {user?.name}</h2>
      <p>Role: {user?.role}</p>
      <button onClick={logout}>Logout</button>
    </div>
  );
}