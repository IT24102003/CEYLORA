import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ToastProvider, ConfirmProvider } from "../components/ui";
import AgentMonitorPage from "./AgentMonitorPage";
import api from "../services/api";

// Replace the real axios instance so no HTTP request is ever sent.
vi.mock("../services/api", () => ({ default: { get: vi.fn(), put: vi.fn() } }));

const workflow = {
  id: 19,
  bookingId: 14,
  status: "PendingApproval",
  objective: "3 day trip to Kandy for 7 people",
  logs: [],
};

function renderPage() {
  return render(
    <ToastProvider>
      <ConfirmProvider>
        <AgentMonitorPage />
      </ConfirmProvider>
    </ToastProvider>,
  );
}

describe("AgentMonitorPage (RE-05)", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("shows the empty state when no workflow is waiting for approval", async () => {
    api.get.mockResolvedValueOnce({ data: [] });

    renderPage();

    expect(await screen.findByText("All caught up")).toBeInTheDocument();
  });

  it("shows an error state when the pending workflows cannot be loaded", async () => {
    api.get.mockRejectedValueOnce(new Error("Network Error"));

    renderPage();

    expect(await screen.findByText("Failed to load pending workflows.")).toBeInTheDocument();
  });

  it("calls the approve endpoint with status Approved and reloads the list", async () => {
    api.get.mockResolvedValueOnce({ data: [workflow] }).mockResolvedValueOnce({ data: [] });
    api.put.mockResolvedValueOnce({ data: {} });
    const user = userEvent.setup();
    renderPage();

    await user.click(await screen.findByRole("button", { name: /^approve$/i }));

    expect(api.put).toHaveBeenCalledWith("/agent-workflows/19/approve", { approvalStatus: "Approved" });
    expect(await screen.findByText("All caught up")).toBeInTheDocument(); // list refreshed
  });

  it("asks for confirmation before rejecting and does nothing if cancelled", async () => {
    api.get.mockResolvedValueOnce({ data: [workflow] });
    const user = userEvent.setup();
    renderPage();

    await user.click(await screen.findByRole("button", { name: /^reject$/i }));
    await user.click(await screen.findByRole("button", { name: /cancel/i }));

    expect(api.put).not.toHaveBeenCalled();
  });

  it("rejects the plan after the admin confirms", async () => {
    api.get.mockResolvedValueOnce({ data: [workflow] }).mockResolvedValueOnce({ data: [] });
    api.put.mockResolvedValueOnce({ data: {} });
    const user = userEvent.setup();
    renderPage();

    await user.click(await screen.findByRole("button", { name: /^reject$/i }));
    await user.click(await screen.findByRole("button", { name: /reject plan/i }));

    await waitFor(() =>
      expect(api.put).toHaveBeenCalledWith("/agent-workflows/19/approve", { approvalStatus: "Rejected" }),
    );
  });
});
