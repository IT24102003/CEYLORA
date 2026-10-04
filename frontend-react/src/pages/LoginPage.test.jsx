import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import LoginPage from "./LoginPage";

const mockLogin = vi.fn();
const mockUseAuth = vi.fn();
vi.mock("../context/AuthContext", () => ({
  useAuth: () => mockUseAuth(),
}));

function renderLoginPage() {
  return render(
    <MemoryRouter initialEntries={["/login"]}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/analytics" element={<div>Analytics dashboard</div>} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("LoginPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockUseAuth.mockReturnValue({ user: null, login: mockLogin });
  });

  it("renders email and password fields and a sign-in button", () => {
    renderLoginPage();

    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i, { selector: "input" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /sign in/i })).toBeInTheDocument();
  });

  it("redirects straight to /analytics if already logged in", () => {
    mockUseAuth.mockReturnValue({ user: { userId: 1, role: "Admin" }, login: mockLogin });

    renderLoginPage();

    expect(screen.getByText("Analytics dashboard")).toBeInTheDocument();
  });

  it("submits the typed credentials and navigates to /analytics on success", async () => {
    mockLogin.mockResolvedValueOnce({ userId: 1, role: "Admin" });
    const user = userEvent.setup();
    renderLoginPage();

    await user.type(screen.getByLabelText(/email/i), "admin@ceylora.com");
    await user.type(screen.getByLabelText(/password/i, { selector: "input" }), "correct-password");
    await user.click(screen.getByRole("button", { name: /sign in/i }));

    expect(mockLogin).toHaveBeenCalledWith("admin@ceylora.com", "correct-password");
    await waitFor(() => expect(screen.getByText("Analytics dashboard")).toBeInTheDocument());
  });

  it("shows the error message and stays on the page when login fails", async () => {
    mockLogin.mockRejectedValueOnce({ response: { data: { message: "Invalid email or password." } } });
    const user = userEvent.setup();
    renderLoginPage();

    await user.type(screen.getByLabelText(/email/i), "admin@ceylora.com");
    await user.type(screen.getByLabelText(/password/i, { selector: "input" }), "wrong-password");
    await user.click(screen.getByRole("button", { name: /sign in/i }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Invalid email or password.");
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument(); // still on the login page
  });

  it("rejects a non-Admin account with the dashboard's own error message", async () => {
    mockLogin.mockRejectedValueOnce(new Error("Only Admin accounts can access this dashboard."));
    const user = userEvent.setup();
    renderLoginPage();

    await user.type(screen.getByLabelText(/email/i), "tourist@ceylora.com");
    await user.type(screen.getByLabelText(/password/i, { selector: "input" }), "password123");
    await user.click(screen.getByRole("button", { name: /sign in/i }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Only Admin accounts can access this dashboard.");
  });
});
