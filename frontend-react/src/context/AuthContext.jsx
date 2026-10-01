import { createContext, useContext, useState } from "react";
import api from "../services/api";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  // Restore the session synchronously so protected routes never flash the login page.
  const [user, setUser] = useState(() => {
    try {
      const token = localStorage.getItem("ceylora_token");
      const savedUser = localStorage.getItem("ceylora_user");
      return token && savedUser ? JSON.parse(savedUser) : null;
    } catch {
      return null;
    }
  });
  const loading = false;

  const login = async (email, password) => {
    const response = await api.post("/auth/login", { email, password });
    const { token, userId, name, email: userEmail, role } = response.data;

    if (role !== "Admin") {
      throw new Error("Only Admin accounts can access this dashboard.");
    }

    const userData = { userId, name, email: userEmail, role };
    localStorage.setItem("ceylora_token", token);
    localStorage.setItem("ceylora_user", JSON.stringify(userData));
    setUser(userData);
    return userData;
  };

  const logout = () => {
    localStorage.removeItem("ceylora_token");
    localStorage.removeItem("ceylora_user");
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}