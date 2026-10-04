import axios from "axios";

// Defaults to a local `dotnet run` instance. Set VITE_API_ROOT (e.g. in a
// `.env.production` file, or as a build-time env var) to point this build at
// the deployed backend instead — e.g. https://ceylora-production.up.railway.app
export const API_ROOT = import.meta.env.VITE_API_ROOT || "http://localhost:5220";

const api = axios.create({
  baseURL: `${API_ROOT}/api`,
  // Without this, a slow/stuck backend (e.g. a DB connection-pool wait) leaves
  // the page spinning forever with no error and nothing in the console — the
  // request never fails, it just never resolves. 15s gives a clear timeout
  // error the UI can show instead.
  timeout: 15000,
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

// An expired or invalid token makes every call fail with 401 — drop the session and send the admin back to sign in.
api.interceptors.response.use(
  (res) => res,
  (error) => {
    const url = error.config?.url ?? "";
    if (error.response?.status === 401 && !url.includes("/auth/login") && localStorage.getItem("ceylora_token")) {
      localStorage.removeItem("ceylora_token");
      localStorage.removeItem("ceylora_user");
      sessionStorage.setItem("ceylora_session_expired", "1");
      window.location.assign("/login");
    }
    return Promise.reject(error);
  },
);

export default api;