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