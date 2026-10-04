import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { AuthProvider, useAuth } from "./AuthContext";
import api from "../services/api";

// AuthContext talks to the backend through services/api.js — mock that boundary so
// these tests never make a real network call.
vi.mock("../services/api", () => ({
  default: { post: vi.fn() },
}));

describe("AuthContext", () => {
  beforeEach(() => {
    localStorage.clear();
    vi.clearAllMocks();
  });

  it("starts with no user when localStorage is empty", () => {
    const { result } = renderHook(() => useAuth(), { wrapper: AuthProvider });
    expect(result.current.user).toBeNull();
  });

  it("restores the session from localStorage on mount (no login-page flash)", () => {
    localStorage.setItem("ceylora_token", "existing-token");
    localStorage.setItem(
      "ceylora_user",
      JSON.stringify({ userId: 1, name: "Admin", email: "admin@ceylora.com", role: "Admin" }),
    );

    const { result } = renderHook(() => useAuth(), { wrapper: AuthProvider });

    expect(result.current.user).toEqual({
      userId: 1, name: "Admin", email: "admin@ceylora.com", role: "Admin",
    });
  });

  it("login() stores the token/user and updates state for an Admin account", async () => {
    api.post.mockResolvedValueOnce({
      data: { token: "jwt-token", userId: 5, name: "Site Admin", email: "a@ceylora.com", role: "Admin" },
    });

    const { result } = renderHook(() => useAuth(), { wrapper: AuthProvider });

    await act(async () => {
      await result.current.login("a@ceylora.com", "password123");
    });

    expect(localStorage.getItem("ceylora_token")).toBe("jwt-token");
    expect(JSON.parse(localStorage.getItem("ceylora_user"))).toMatchObject({ role: "Admin" });
    await waitFor(() => expect(result.current.user).not.toBeNull());
    expect(result.current.user.role).toBe("Admin");
  });

  // Business rule: this is an ADMIN dashboard — a Tourist/Guide/VehicleOwner account
  // authenticating correctly must still be rejected and never get a session.
  it("login() rejects a non-Admin account even with correct credentials", async () => {
    api.post.mockResolvedValueOnce({
      data: { token: "jwt-token", userId: 9, name: "Some Tourist", email: "t@ceylora.com", role: "Tourist" },
    });

    const { result } = renderHook(() => useAuth(), { wrapper: AuthProvider });

    await expect(
      act(async () => {
        await result.current.login("t@ceylora.com", "password123");
      }),
    ).rejects.toThrow("Only Admin accounts can access this dashboard.");

    expect(localStorage.getItem("ceylora_token")).toBeNull();
    expect(result.current.user).toBeNull();
  });

  it("logout() clears the stored session", async () => {
    localStorage.setItem("ceylora_token", "t");
    localStorage.setItem("ceylora_user", JSON.stringify({ userId: 1, role: "Admin" }));

    const { result } = renderHook(() => useAuth(), { wrapper: AuthProvider });
    act(() => result.current.logout());

    expect(localStorage.getItem("ceylora_token")).toBeNull();
    expect(localStorage.getItem("ceylora_user")).toBeNull();
    expect(result.current.user).toBeNull();
  });
});
