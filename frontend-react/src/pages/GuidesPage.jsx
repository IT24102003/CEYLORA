import { useState } from "react";
import { Compass, Plus, Star, Trash2 } from "lucide-react";
import api from "../services/api";
import {
  Alert, Avatar, Button, Card, DataTable, Drawer, EmptyState, ErrorState, IconButton, Input, PageHeader, SearchInput,
  Select, Switch, TableSkeleton, Toolbar, useConfirm, useToast,
} from "../components/ui";
import { errorMessage, useAction, useRemote } from "../lib/hooks";

const EMPTY = { search: "", region: "", available: "" };

export default function GuidesPage() {
  const [draft, setDraft] = useState(EMPTY);
  const [applied, setApplied] = useState(EMPTY);
  const [showAdd, setShowAdd] = useState(false);
  const toast = useToast();
  const confirm = useConfirm();
  const [busy, act] = useAction();

  const { data: guides, loading, error, reload } = useRemote(async () => {
    const params = { pageSize: 50 };
    if (applied.region) params.region = applied.region;
    if (applied.search) params.search = applied.search;
    if (applied.available) params.available = applied.available;
    return (await api.get("/guides", { params })).data.items;
  }, [applied]);

  // Users with role=Guide, used by the "add profile" form.
  const { data: guideUsers, reload: reloadUsers } = useRemote(async () => (await api.get("/users", { params: { role: "Guide" } })).data, []);

  const set = (k) => (e) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = () => setApplied(draft);
  const reset = () => { setDraft(EMPTY); setApplied(EMPTY); };
  const activeFilters = [draft.region, draft.available].filter(Boolean).length;
  const isFiltered = Object.values(applied).some(Boolean);

  const toggleAvailability = (g) =>
    act(g.id, async () => {
      try {
        await api.put(`/guides/${g.id}/availability`, !g.isAvailable);
        toast.success(`${g.name ?? "Guide"} is now ${g.isAvailable ? "unavailable" : "available"}.`);
        reload();
      } catch (err) {
        toast.error(errorMessage(err, "Failed to update availability."));
      }
    });

  const handleDelete = async (g) => {
    const ok = await confirm({ title: `Delete ${g.name ?? "this guide"}?`, message: "Their guide profile will be removed. The user account itself is kept.", confirmLabel: "Delete guide" });
    if (!ok) return;
    try {
      await api.delete(`/guides/${g.id}`);
      toast.success("Guide deleted.");
      reload();
      reloadUsers();
    } catch (err) {
      toast.error(errorMessage(err, "Failed to delete guide."));
    }
  };

  const columns = [
    {
      key: "guide", header: "Guide", primary: true,
      render: (g) => (
        <div className="row">
          <Avatar name={g.name} src={g.profilePictureUrl} />
          <div style={{ minWidth: 0 }}>
            <div><strong>{g.name ?? "—"}</strong></div>
            <div className="cell-sub">#{g.id}{g.country ? ` · ${g.country}` : ""}</div>
          </div>
        </div>
      ),
    },
    { key: "phone", header: "Phone", render: (g) => g.mobileNumber ?? "—" },
    { key: "languages", header: "Languages" },
    { key: "region", header: "Region" },
    {
      key: "rating", header: "Rating",
      render: (g) => g.rating != null ? <span className="row" style={{ gap: 4 }}><Star size={14} fill="currentColor" style={{ color: "var(--c-warning)" }} aria-hidden="true" />{g.rating.toFixed(1)}</span> : "—",
    },
    {
      key: "available", header: "Available",
      render: (g) => <Switch checked={!!g.isAvailable} disabled={busy === g.id} onChange={() => toggleAvailability(g)} label={<span className="sr-only">{g.isAvailable ? "Available" : "Unavailable"} — toggle availability for {g.name}</span>} />,
    },
    { key: "actions", actions: true, render: (g) => <IconButton icon={Trash2} label={`Delete ${g.name ?? "guide"}`} size="sm" variant="soft-danger" onClick={() => handleDelete(g)} /> },
  ];

  const filters = (
    <>
      <Input aria-label="Region" placeholder="Region" value={draft.region} onChange={set("region")} />
      <Select aria-label="Availability" value={draft.available} onChange={set("available")} placeholder="Any availability" options={[{ value: "true", label: "Available only" }, { value: "false", label: "Unavailable only" }]} />
    </>
  );

  return (
    <div className="page">
      <PageHeader
        title="Guides"
        subtitle="Local guides who lead trips. Toggle availability to control who can be assigned."
        actions={<Button variant="primary" icon={Plus} onClick={() => setShowAdd(true)}>Add guide profile</Button>}
      />

      <Toolbar
        search={<SearchInput value={draft.search} onChange={(v) => setDraft((d) => ({ ...d, search: v }))} onEnter={apply} placeholder="Search by language or region…" />}
        filters={filters}
        activeFilters={activeFilters}
        onApply={apply}
        onReset={reset}
      />

      {loading && !guides ? (
        <Card><TableSkeleton /></Card>
      ) : error && !guides ? (
        <Card><ErrorState text="Guides could not be loaded." onRetry={reload} /></Card>
      ) : guides.length === 0 ? (
        <Card>
          <EmptyState
            icon={Compass}
            title={isFiltered ? "No guides match your filters" : "No guides yet"}
            text={isFiltered ? "Try removing a filter or searching for something else." : "Create a guide profile for a registered Guide account to get started."}
            action={isFiltered ? <Button onClick={reset}>Clear filters</Button> : <Button variant="primary" icon={Plus} onClick={() => setShowAdd(true)}>Add guide profile</Button>}
          />
        </Card>
      ) : (
        <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          <DataTable columns={columns} rows={guides} caption="Guides" />
        </div>
      )}

      {showAdd && (
        <AddGuideDrawer
          users={(guideUsers ?? []).filter((u) => !u.hasGuideProfile)}
          hasAnyGuideUser={(guideUsers ?? []).length > 0}
          onClose={() => setShowAdd(false)}
          onCreated={() => { setShowAdd(false); toast.success("Guide profile created."); reload(); reloadUsers(); }}
        />
      )}
    </div>
  );
}

function AddGuideDrawer({ users, hasAnyGuideUser, onClose, onCreated }) {
  const [userId, setUserId] = useState("");
  const [region, setRegion] = useState("");
  const [languages, setLanguages] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const submit = async (e) => {
    e.preventDefault();
    if (!userId || !region.trim()) { setError("Please pick a user and enter a region."); return; }
    setSubmitting(true);
    setError("");
    try {
      await api.post("/guides", { userId: Number(userId), languages: languages.trim() || null, region: region.trim(), isAvailable: true });
      onCreated();
    } catch (err) {
      setError(errorMessage(err, "Failed to create guide profile."));
      setSubmitting(false);
    }
  };

  return (
    <Drawer
      title="Add guide profile"
      description="Link a guide profile to an existing account with the Guide role."
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button type="submit" form="add-guide" variant="primary" loading={submitting}>Create profile</Button>
        </>
      }
    >
      <form id="add-guide" className="stack" onSubmit={submit}>
        {error && <Alert tone="error">{error}</Alert>}
        <Select
          label="User account"
          required
          placeholder="Select a user"
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          options={users.map((u) => ({ value: u.id, label: `${u.name} (${u.email})` }))}
          hint={!hasAnyGuideUser ? 'No accounts with role "Guide" have registered yet.' : users.length === 0 ? "Every Guide account already has a linked profile." : undefined}
        />
        <Input label="Region" required placeholder="e.g. Kandy" value={region} onChange={(e) => setRegion(e.target.value)} />
        <Input label="Languages" hint="Optional — comma separated." placeholder="e.g. English, Sinhala" value={languages} onChange={(e) => setLanguages(e.target.value)} />
      </form>
    </Drawer>
  );
}
