import { lazy, Suspense } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext";
import ProtectedRoute from "./components/ProtectedRoute";
import AdminLayout from "./components/AdminLayout";
import LoginPage from "./pages/LoginPage";
import { ConfirmProvider, ToastProvider, Spinner } from "./components/ui";

// Route-level code splitting: each admin page is its own chunk.
const AnalyticsPage = lazy(() => import("./pages/AnalyticsPage"));
const AgentMonitorPage = lazy(() => import("./pages/AgentMonitorPage"));
const DestinationsPage = lazy(() => import("./pages/DestinationsPage"));
const PackagesPage = lazy(() => import("./pages/PackagesPage"));
const HotelsPage = lazy(() => import("./pages/HotelsPage"));
const BookingsPage = lazy(() => import("./pages/BookingsPage"));
const GuidesPage = lazy(() => import("./pages/GuidesPage"));
const VehiclesPage = lazy(() => import("./pages/VehiclesPage"));
const ReviewsPage = lazy(() => import("./pages/ReviewsPage"));
const VerificationsPage = lazy(() => import("./pages/VerificationsPage"));
const ReportsPage = lazy(() => import("./pages/ReportsPage"));
const UsersPage = lazy(() => import("./pages/UsersPage"));
const PaymentsPage = lazy(() => import("./pages/PaymentsPage"));

const PageLoader = () => (
  <div style={{ display: "grid", placeItems: "center", minHeight: "50vh" }}>
    <Spinner large />
  </div>
);

function App() {
  return (
    <ToastProvider>
      <ConfirmProvider>
        <AuthProvider>
          <BrowserRouter>
            <Routes>
              <Route path="/login" element={<LoginPage />} />

              {/* Every admin page shares the sidebar / bottom-nav shell from AdminLayout. */}
              <Route
                element={
                  <ProtectedRoute>
                    <AdminLayout />
                  </ProtectedRoute>
                }
              >
                {[
                  ["/analytics", AnalyticsPage],
                  ["/agent-monitor", AgentMonitorPage],
                  ["/destinations", DestinationsPage],
                  ["/packages", PackagesPage],
                  ["/hotels", HotelsPage],
                  ["/bookings", BookingsPage],
                  ["/guides", GuidesPage],
                  ["/vehicles", VehiclesPage],
                  ["/reviews", ReviewsPage],
                  ["/verifications", VerificationsPage],
                  ["/reports", ReportsPage],
                  ["/users", UsersPage],
                  ["/payments", PaymentsPage],
                ].map(([path, Page]) => (
                  <Route
                    key={path}
                    path={path}
                    element={<Suspense fallback={<PageLoader />}><Page /></Suspense>}
                  />
                ))}
              </Route>

              <Route path="/dashboard" element={<Navigate to="/analytics" replace />} />
              <Route path="/" element={<Navigate to="/analytics" replace />} />
              <Route path="*" element={<Navigate to="/analytics" replace />} />
            </Routes>
          </BrowserRouter>
        </AuthProvider>
      </ConfirmProvider>
    </ToastProvider>
  );
}

export default App;
