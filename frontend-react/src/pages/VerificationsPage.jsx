import { useState } from "react";
import { Car, Check, FileText, Image as ImageIcon, ShieldCheck, X } from "lucide-react";
import api, { API_ROOT } from "../services/api";
import { Avatar, Badge, Button, Card, CardsSkeleton, EmptyState, ErrorState, Input, PageHeader, Tabs, useConfirm, useToast } from "../components/ui";
import { errorMessage, useAction, useRemote } from "../lib/hooks";


function ApplicantCard({ kind, person, busy, note, onNote, onDecide, children }) {
  const key = `${kind}-${person.id}`;
  const working = busy === key;
  return (
    <Card pad className="item-card">
      <div className="item-card__head">
        <div className="row" style={{ alignItems: "flex-start", flex: "1 1 320px" }}>
          <Avatar name={person.name} size={44} />
          <div style={{ minWidth: 0 }}>
            <h2 className="card__title">{person.name}</h2>
            <div className="muted truncate">{person.email}</div>
          </div>
        </div>
        <div className="item-card__actions">
          <Button variant="success" icon={Check} loading={working} disabled={!!busy && !working} onClick={() => onDecide(person, true)}>Approve</Button>
          <Button variant="soft-danger" icon={X} disabled={!!busy} onClick={() => onDecide(person, false)}>Reject</Button>
        </div>
      </div>

      <dl className="kv" style={{ marginTop: "var(--space-4)", gridTemplateColumns: "repeat(auto-fit, minmax(160px, max-content))", gap: "var(--space-3) var(--space-8)" }}>
        {[
          ["Age", person.age], ["Region", person.region], ["Country", person.country],
          ["NIC", person.nicNumber], ["Phone", person.mobileNumber], ["Languages", person.languages],
        ].filter(([, v]) => v !== undefined).map(([k, v]) => (
          <div key={k}><dt>{k}</dt><dd>{v ?? "—"}</dd></div>
        ))}
      </dl>

      {children}

      <div style={{ marginTop: "var(--space-4)", maxWidth: 420 }}>
        <Input
          label="Rejection reason"
          hint="Optional — shared with the applicant if you reject."
          placeholder="e.g. Photo is unreadable"
          value={note || ""}
          onChange={(e) => onNote(key, e.target.value)}
        />
      </div>
    </Card>
  );
}

const DocLink = ({ href, icon: Icon, children }) => (
  <a className="chip-link" href={`${API_ROOT}${href}`} target="_blank" rel="noreferrer">
    <Icon size={14} aria-hidden="true" /> {children}<span className="sr-only"> (opens in a new tab)</span>
  </a>
);

export default function VerificationsPage() {
  const toast = useToast();
  const confirm = useConfirm();
  const [busy, act] = useAction();
  const [tab, setTab] = useState("guides");
  const [notes, setNotes] = useState({});

  const { data, loading, error, reload } = useRemote(async () => {
    const [g, v] = await Promise.all([api.get("/guides/pending"), api.get("/vehicle-owners/pending")]);
    return { guides: g.data, owners: v.data };
  }, []);

  const decide = (kind) => async (person, approve) => {
    if (!approve) {
      const ok = await confirm({
        title: `Reject ${person.name}?`,
        message: "They will be told their application was not approved.",
        confirmLabel: "Reject application",
      });
      if (!ok) return;
    }
    const key = `${kind}-${person.id}`;
    await act(key, async () => {
      try {
        await api.put(`/${kind === "guide" ? "guides" : "vehicle-owners"}/${person.id}/verify`, { approve, note: notes[key] || null });
        toast.success(approve ? `${person.name} approved.` : `${person.name} rejected.`);
        reload();
      } catch (err) {
        toast.error(errorMessage(err, "Failed to update verification status."));
      }
    });
  };
  const setNote = (key, value) => setNotes((s) => ({ ...s, [key]: value }));

  const tabs = [
    { value: "guides", label: "Guides", count: data?.guides.length },
    { value: "owners", label: "Vehicle owners", count: data?.owners.length },
  ];

  return (
    <div className="page">
      <PageHeader title="Verifications" subtitle="Guide and vehicle-owner accounts wait here until you review their details and documents." />

      <div style={{ marginBottom: "var(--space-4)" }}><Tabs label="Application type" tabs={tabs} value={tab} onChange={setTab} /></div>

      {loading && !data ? (
        <CardsSkeleton />
      ) : error && !data ? (
        <Card><ErrorState text="Pending applications could not be loaded." onRetry={reload} /></Card>
      ) : tab === "guides" ? (
        data.guides.length === 0 ? (
          <Card><EmptyState icon={ShieldCheck} title="No pending guide applications" text="New guide sign-ups will show up here for review." /></Card>
        ) : (
          data.guides.map((g) => (
            <ApplicantCard key={g.id} kind="guide" person={g} busy={busy} note={notes[`guide-${g.id}`]} onNote={setNote} onDecide={decide("guide")}>
              {g.tourismIdPhotoUrl && (
                <div className="chips" style={{ marginTop: "var(--space-4)" }}>
                  <DocLink href={g.tourismIdPhotoUrl} icon={FileText}>Tourism ID</DocLink>
                </div>
              )}
            </ApplicantCard>
          ))
        )
      ) : data.owners.length === 0 ? (
        <Card><EmptyState icon={Car} title="No pending vehicle owner applications" text="New vehicle owner sign-ups will show up here for review." /></Card>
      ) : (
        data.owners.map((o) => (
          <ApplicantCard key={o.id} kind="owner" person={o} busy={busy} note={notes[`owner-${o.id}`]} onNote={setNote} onDecide={decide("owner")}>
            <div className="chips" style={{ marginTop: "var(--space-4)" }}>
              {o.drivingLicensePhotoUrl && <DocLink href={o.drivingLicensePhotoUrl} icon={FileText}>Driving licence</DocLink>}
            </div>
            {o.vehicles?.map((v) => (
              <div key={v.id} className="panel-soft" style={{ marginTop: "var(--space-3)" }}>
                <div className="row row--wrap">
                  <strong>{v.name}</strong>
                  <Badge>{v.type}</Badge>
                  <span className="muted">{v.manufacturerYear} · {v.capacity} seats</span>
                </div>
                {v.images?.length > 0 && (
                  <div className="chips" style={{ marginTop: "var(--space-2)" }}>
                    {v.images.map((img, i) => <DocLink key={i} href={img} icon={ImageIcon}>Photo {i + 1}</DocLink>)}
                  </div>
                )}
              </div>
            ))}
          </ApplicantCard>
        ))
      )}
    </div>
  );
}
