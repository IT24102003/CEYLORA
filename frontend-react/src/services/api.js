import axios from "axios";

const api = axios.create({
  baseURL: "http://localhost:5220/api",
});

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