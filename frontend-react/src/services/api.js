import axios from "axios";

export const API_ROOT = "http://localhost:5220";

const api = axios.create({
  baseURL: `${API_ROOT}/api`,
});

/** Uploaded files come back as relative paths ("/uploads/..."); make them absolute. */
export const assetUrl = (path) => {
  if (!path) return null;
  return /^https?:\/\//i.test(path) ? path : `${API_ROOT}${path.startsWith("/") ? "" : "/"}${path}`;
};

export const getWeather = (lat, lon) => api.get("/weather/forecast", { params: { lat, lon } });

// Attach JWT token to every request automatically
api.interceptors.request.use((config) => {
  const token = localStorage.getItem("ceylora_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export default api;