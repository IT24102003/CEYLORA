import { createContext, useContext, useState, useEffect } from "react";
import api from "../services/api";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem("ceylora_token");
    const savedUser = localStorage.getItem("ceylora_user");
    if (token && savedUser) {
      setUser(JSON.parse(savedUser));
    }
    setLoading(false);
  }, []);

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