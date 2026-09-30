import { useState, useEffect } from "react";
import api from "../services/api";

export default function AgentMonitorPage() {
  const [workflows, setWorkflows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [expandedId, setExpandedId] = useState(null);

  const fetchPending = async () => {
    setLoading(true);
    try {
      const res = await api.get("/agent-workflows/pending-approval");
      setWorkflows(res.data);
    } catch (err) {
      setError("Failed to load pending workflows.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPending();
  }, []);

  const handleDecision = async (id, status) => {
    try {
      await api.put(`/agent-workflows/${id}/approve`, { approvalStatus: status });
      fetchPending(); // refresh list after decision
    } catch (err) {
      alert("Failed to update approval status.");
    }
  };

  if (loading) return <p style={{ padding: 20 }}>Loading pending workflows...</p>;
  if (error) return <p style={{ padding: 20, color: "red" }}>{error}</p>;

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Agent Workflow Monitor</h2>
      <p>Workflows awaiting human approval (spec-required high-impact action gate)</p>

      {workflows.length === 0 && <p>No pending workflows. All caught up!</p>}

      {workflows.map((wf) => (
        <div
          key={wf.id}
          style={{
            border: "1px solid #ccc",
            borderRadius: 8,
            padding: 16,
            marginBottom: 16,
          }}
        >
          <div style={{ display: "flex", justifyContent: "space-between" }}>
            <div>
              <strong>Workflow #{wf.id}</strong> — Booking #{wf.bookingId}
              <p style={{ margin: "4px 0" }}>Objective: {wf.objective}</p>
              <p style={{ margin: 0, color: "#666" }}>Status: {wf.status}</p>

              {wf.tourist && (
                <div style={{ marginTop: 10, background: "#f5f5f5", padding: 10, borderRadius: 6, fontSize: 13 }}>
                  <strong>Tourist details</strong>
                  <div>Name: {wf.tourist.name}</div>
                  <div>Email: {wf.tourist.email}</div>
                  <div>Phone: {wf.tourist.mobileNumber ?? "—"}</div>
                  <div>Country: {wf.tourist.country ?? "—"}</div>
                </div>
              )}

              {wf.plan && (
                <div style={{ marginTop: 8, background: "#eef6ff", padding: 10, borderRadius: 6, fontSize: 13 }}>
                  <strong>Trip plan</strong>
                  <div>Days: {wf.plan.dayCount}</div>
                  {wf.plan.plannedStartDate && (
                    <div>Planned start date: {new Date(wf.plan.plannedStartDate).toLocaleDateString()}</div>
                  )}
                  <div>Destinations: {wf.plan.destinationNames?.length ? wf.plan.destinationNames.join(", ") : "—"}</div>
                  <div>Hotel: {wf.plan.hotelName ?? "—"}</div>
                  <div>Guide: {wf.plan.guideName ?? "—"}</div>
                  <div>Vehicle: {wf.plan.vehicleName ?? "—"}</div>
                  {wf.plan.estimatedTotalCost != null && (
                    <div>Estimated cost: LKR {wf.plan.estimatedTotalCost}</div>
                  )}

                  {wf.plan.days?.length > 0 && (
                    <div style={{ marginTop: 8 }}>
                      <strong>Full day-by-day plan</strong>
                      {wf.plan.days.map((d) => (
                        <div
                          key={d.dayNumber}
                          style={{ marginTop: 4, paddingLeft: 8, borderLeft: "2px solid #1565c0" }}
                        >
                          <div style={{ fontWeight: 600 }}>Day {d.dayNumber}</div>
                          <div>
                            Destinations: {d.destinationNames?.length ? d.destinationNames.join(", ") : "—"}
                          </div>
                          <div>Hotel: {d.hotelName ?? "—"}</div>
                          {d.activities && <div>Activities: {d.activities}</div>}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
            <div>
              <button
                onClick={() => handleDecision(wf.id, "Approved")}
                style={{ marginRight: 8, background: "#2e7d32", color: "#fff", padding: "6px 14px", border: "none", borderRadius: 4 }}
              >
                Approve
              </button>
              <button
                onClick={() => handleDecision(wf.id, "Rejected")}
                style={{ marginRight: 8, background: "#c62828", color: "#fff", padding: "6px 14px", border: "none", borderRadius: 4 }}
              >
                Reject
              </button>
              <button
                onClick={() => handleDecision(wf.id, "RevisionRequested")}
                style={{ background: "#ef6c00", color: "#fff", padding: "6px 14px", border: "none", borderRadius: 4 }}
              >
                Request Revision
              </button>
            </div>
          </div>

          <button
            onClick={() => setExpandedId(expandedId === wf.id ? null : wf.id)}
            style={{ marginTop: 10, background: "none", border: "none", color: "#1565c0", cursor: "pointer" }}
          >
            {expandedId === wf.id ? "Hide" : "View"} Execution Log ({wf.logs?.length || 0} steps)
          </button>

          {expandedId === wf.id && (
            <div style={{ marginTop: 10, background: "#f5f5f5", padding: 10, borderRadius: 6 }}>
              {wf.logs?.map((log, i) => (
                <div key={i} style={{ marginBottom: 8, fontSize: 13 }}>
                  <strong>{log.agentName}</strong> — {log.stepName}
                  <p style={{ margin: "2px 0", color: "#555" }}>{log.output}</p>
                </div>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}