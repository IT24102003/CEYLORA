import { useState } from "react";
import { Check, ChevronDown, MessageSquareWarning, PartyPopper, X } from "lucide-react";
import api from "../services/api";
import { Badge, Button, Card, CardsSkeleton, Collapse, EmptyState, ErrorState, PageHeader, useConfirm, useToast } from "../components/ui";
import { errorMessage, formatLKR, useAction, useRemote } from "../lib/hooks";

const dash = (v) => v ?? "—";

function Section({ title, children }) {
  return (
    <div className="panel-soft">
      <h3 className="section-title" style={{ fontSize: "var(--fs-sm)", marginBottom: "var(--space-2)" }}>{title}</h3>
      {children}
    </div>
  );
}

function WorkflowCard({ wf, busy, onDecide }) {
  const [open, setOpen] = useState(false);
  const logCount = wf.logs?.length || 0;

  return (
    <Card pad className="item-card">
      <div className="item-card__head">
        <div style={{ minWidth: 0, flex: "1 1 320px" }}>
          <div className="row row--wrap">
            <h2 className="card__title">Workflow #{wf.id}</h2>
            <Badge tone="warning" dot>{wf.status}</Badge>
            <Badge>Booking #{wf.bookingId}</Badge>
          </div>
          <p style={{ marginTop: 6, color: "var(--c-text-2)" }}>{wf.objective}</p>
        </div>
        <div className="item-card__actions">
          <Button variant="success" icon={Check} loading={busy === `${wf.id}-Approved`} disabled={!!busy} onClick={() => onDecide(wf, "Approved")}>Approve</Button>
          <Button icon={MessageSquareWarning} loading={busy === `${wf.id}-RevisionRequested`} disabled={!!busy} onClick={() => onDecide(wf, "RevisionRequested")}>Request revision</Button>
          <Button variant="soft-danger" icon={X} loading={busy === `${wf.id}-Rejected`} disabled={!!busy} onClick={() => onDecide(wf, "Rejected")}>Reject</Button>
        </div>
      </div>

      <div className="dash-grid" style={{ marginTop: "var(--space-4)" }}>
        {wf.tourist && (
          <Section title="Tourist">
            <dl className="kv">
              <dt>Name</dt><dd>{wf.tourist.name}</dd>
              <dt>Email</dt><dd>{wf.tourist.email}</dd>
              <dt>Phone</dt><dd>{dash(wf.tourist.mobileNumber)}</dd>
              <dt>Country</dt><dd>{dash(wf.tourist.country)}</dd>
            </dl>
          </Section>
        )}
        {wf.plan && (
          <Section title="Trip plan">
            <dl className="kv">
              <dt>Days</dt><dd>{wf.plan.dayCount}</dd>
              {wf.plan.plannedStartDate && <><dt>Start date</dt><dd>{new Date(wf.plan.plannedStartDate).toLocaleDateString()}</dd></>}
              <dt>Destinations</dt><dd>{wf.plan.destinationNames?.length ? wf.plan.destinationNames.join(", ") : "—"}</dd>
              <dt>Hotel</dt><dd>{dash(wf.plan.hotelName)}</dd>
              <dt>Guide</dt><dd>{dash(wf.plan.guideName)}</dd>
              <dt>Vehicle</dt><dd>{dash(wf.plan.vehicleName)}</dd>
              {wf.plan.estimatedTotalCost != null && <><dt>Est. cost</dt><dd className="mono">{formatLKR(wf.plan.estimatedTotalCost)}</dd></>}
            </dl>
          </Section>
        )}
      </div>

      {wf.plan?.days?.length > 0 && (
        <div style={{ marginTop: "var(--space-4)" }}>
          <h3 className="section-title" style={{ fontSize: "var(--fs-sm)" }}>Day-by-day plan</h3>
          <ol className="timeline">
            {wf.plan.days.map((d) => (
              <li key={d.dayNumber}>
                <strong>Day {d.dayNumber}</strong>
                <div className="muted" style={{ fontSize: "var(--fs-sm)" }}>
                  {d.destinationNames?.length ? d.destinationNames.join(", ") : "—"} · Stay: {dash(d.hotelName)}
                </div>
                {d.activities && <div style={{ fontSize: "var(--fs-sm)", marginTop: 2 }}>{d.activities}</div>}
              </li>
            ))}
          </ol>
        </div>
      )}

      <Button variant="ghost" size="sm" onClick={() => setOpen((o) => !o)} aria-expanded={open}>
        <ChevronDown size={16} aria-hidden="true" style={{ transform: open ? "rotate(180deg)" : "none", transition: "transform var(--dur-base) var(--ease-out)" }} />
        {open ? "Hide" : "View"} execution log ({logCount} {logCount === 1 ? "step" : "steps"})
      </Button>
      <Collapse open={open}>
        <div className="panel-soft stack" style={{ gap: "var(--space-3)", marginTop: "var(--space-2)" }}>
          {logCount === 0 && <span className="muted">No log entries.</span>}
          {wf.logs?.map((log, i) => (
            <div key={i}>
              <div className="row" style={{ gap: 8 }}><Badge tone="info">{log.agentName}</Badge><strong style={{ fontSize: "var(--fs-sm)" }}>{log.stepName}</strong></div>
              <p className="muted" style={{ marginTop: 4, fontSize: "var(--fs-sm)", whiteSpace: "pre-wrap" }}>{log.output}</p>
            </div>
          ))}
        </div>
      </Collapse>
    </Card>
  );
}

export default function AgentMonitorPage() {
  const toast = useToast();
  const confirm = useConfirm();
  const [busy, act] = useAction();
  const { data: workflows, loading, error, reload } = useRemote(async () => (await api.get("/agent-workflows/pending-approval")).data, []);

  const decide = async (wf, status) => {
    if (status === "Rejected") {
      const ok = await confirm({
        title: `Reject workflow #${wf.id}?`,
        message: "The AI-generated plan will be discarded for this booking.",
        confirmLabel: "Reject plan",
      });
      if (!ok) return;
    }
    await act(`${wf.id}-${status}`, async () => {
      try {
        await api.put(`/agent-workflows/${wf.id}/approve`, { approvalStatus: status });
        toast.success(status === "Approved" ? `Workflow #${wf.id} approved.` : status === "Rejected" ? `Workflow #${wf.id} rejected.` : `Revision requested for workflow #${wf.id}.`);
        reload();
      } catch (err) {
        toast.error(errorMessage(err, "Failed to update approval status."));
      }
    });
  };

  return (
    <div className="page">
      <PageHeader
        title="Agent Workflow Monitor"
        subtitle="AI-planned trips that need a human decision before they go ahead."
        actions={workflows && <Badge tone={workflows.length ? "warning" : "success"} dot>{workflows.length} awaiting approval</Badge>}
      />

      {loading && !workflows ? (
        <CardsSkeleton />
      ) : error && !workflows ? (
        <Card><ErrorState text="Failed to load pending workflows." onRetry={reload} /></Card>
      ) : workflows.length === 0 ? (
        <Card><EmptyState icon={PartyPopper} title="All caught up" text="No workflows are waiting for approval right now." /></Card>
      ) : (
        <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          {workflows.map((wf) => <WorkflowCard key={wf.id} wf={wf} busy={busy} onDecide={decide} />)}
        </div>
      )}
    </div>
  );
}
