import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext";
import ProtectedRoute from "./components/ProtectedRoute";
import LoginPage from "./pages/LoginPage";
import DashboardPage from "./pages/DashboardPage";
import AgentMonitorPage from "./pages/AgentMonitorPage";
import DestinationsPage from "./pages/DestinationsPage";
import PackagesPage from "./pages/PackagesPage";
import HotelsPage from "./pages/HotelsPage";
import BookingsPage from "./pages/BookingsPage";
import GuidesPage from "./pages/GuidesPage";
import VehiclesPage from "./pages/VehiclesPage";

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            path="/dashboard"
            element={
              <ProtectedRoute>
                <DashboardPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/agent-monitor"
            element={
              <ProtectedRoute>
                <AgentMonitorPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/destinations"
            element={
              <ProtectedRoute>
                <DestinationsPage />
              </ProtectedRoute>
            }
          />
          <Route 
            path="/packages" 
            element={
                <ProtectedRoute>
                    <PackagesPage />
                </ProtectedRoute>
            } 
          />
          <Route 
            path="/hotels" 
            element={
                <ProtectedRoute>
                    <HotelsPage />
                </ProtectedRoute>
            } 
          />
          <Route 
            path="/bookings" 
            element={
              <ProtectedRoute>
                    <BookingsPage />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/guides" 
            element={
                <ProtectedRoute>
                    <GuidesPage />
                </ProtectedRoute>
            } 
          />
          <Route 
            path="/vehicles" 
            element={
                <ProtectedRoute>
                    <VehiclesPage />
                </ProtectedRoute>
            } 
          />
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;