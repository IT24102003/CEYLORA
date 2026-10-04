import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import ProtectedRoute from "./ProtectedRoute";

const mockUseAuth = vi.fn();
vi.mock("../context/AuthContext", () => ({
  useAuth: () => mockUseAuth(),
}));

function renderProtected() {
  return render(
    <MemoryRouter initialEntries={["/analytics"]}>
      <Routes>
        <Route path="/login" element={<div>Login page</div>} />
        <Route
          path="/analytics"
          element={
            <ProtectedRoute>
              <div>Secret admin content</div>
            </ProtectedRoute>
          }
        />
      </Routes>
    </MemoryRouter>,
  );
}

describe("ProtectedRoute", () => {
  it("redirects to /login when there is no authenticated user", () => {
    mockUseAuth.mockReturnValue({ user: null, loading: false });

    renderProtected();

    expect(screen.getByText("Login page")).toBeInTheDocument();
    expect(screen.queryByText("Secret admin content")).not.toBeInTheDocument();
  });

  it("renders the protected content when a user is authenticated", () => {
    mockUseAuth.mockReturnValue({ user: { userId: 1, role: "Admin" }, loading: false });

    renderProtected();

    expect(screen.getByText("Secret admin content")).toBeInTheDocument();
  });

  it("shows a spinner instead of redirecting while the auth state is still loading", () => {
    mockUseAuth.mockReturnValue({ user: null, loading: true });

    renderProtected();

    expect(screen.queryByText("Login page")).not.toBeInTheDocument();
    expect(screen.queryByText("Secret admin content")).not.toBeInTheDocument();
  });
});
