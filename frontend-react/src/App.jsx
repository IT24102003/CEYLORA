import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext";
import ProtectedRoute from "./components/ProtectedRoute";
import AdminLayout from "./components/AdminLayout";
import LoginPage from "./pages/LoginPage";
import AgentMonitorPage from "./pages/AgentMonitorPage";
import DestinationsPage from "./pages/DestinationsPage";
import PackagesPage from "./pages/PackagesPage";
import HotelsPage from "./pages/HotelsPage";
import BookingsPage from "./pages/BookingsPage";
import GuidesPage from "./pages/GuidesPage";
import VehiclesPage from "./pages/VehiclesPage";
import ReviewsPage from "./pages/ReviewsPage";
import AnalyticsPage from "./pages/AnalyticsPage";
import VerificationsPage from "./pages/VerificationsPage";

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />

          {/* Every admin page shares the left-side nav from AdminLayout. Logging in (or
              hitting "/" or the old "/dashboard" link) lands on Analytics first. */}
          <Route
            element={
              <ProtectedRoute>
                <AdminLayout />
              </ProtectedRoute>
            }
          >
            <Route path="/analytics" element={<AnalyticsPage />} />
            <Route path="/agent-monitor" element={<AgentMonitorPage />} />
            <Route path="/destinations" element={<DestinationsPage />} />
            <Route path="/packages" element={<PackagesPage />} />
            <Route path="/hotels" element={<HotelsPage />} />
            <Route path="/bookings" element={<BookingsPage />} />
            <Route path="/guides" element={<GuidesPage />} />
            <Route path="/vehicles" element={<VehiclesPage />} />
            <Route path="/reviews" element={<ReviewsPage />} />
            <Route path="/verifications" element={<VerificationsPage />} />
          </Route>

          <Route path="/dashboard" element={<Navigate to="/analytics" replace />} />
          <Route path="/" element={<Navigate to="/analytics" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;