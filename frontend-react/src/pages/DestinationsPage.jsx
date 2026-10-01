import { useState } from "react";
import { CloudRain, MapPin, Pencil, Plus, Sun, Thermometer, Trash2 } from "lucide-react";
import api, { getWeather } from "../services/api";
import {
  Alert, Badge, Button, Card, DataTable, Drawer, EmptyState, ErrorState, IconButton, Input, PageHeader, SearchInput,
  TableSkeleton, Textarea, Thumb, Toolbar, useConfirm, useToast,
} from "../components/ui";
import { errorMessage, useAction, useRemote } from "../lib/hooks";

const EMPTY_FORM = { name: "", region: "", description: "", category: "", imageUrl: "", latitude: "", longitude: "" };
const EMPTY_FILTERS = { search: "", region: "", category: "" };

export default function DestinationsPage() {
  const [draft, setDraft] = useState(EMPTY_FILTERS);
  const [applied, setApplied] = useState(EMPTY_FILTERS);
  const [editing, setEditing] = useState(null); // null | "new" | destination
  const [weather, setWeather] = useState({});
  const [busy, act] = useAction();
  const toast = useToast();
  const confirm = useConfirm();

  const { data: destinations, loading, error, reload } = useRemote(async () => {
    const params = { search: applied.search, pageSize: 50 };
    if (applied.region) params.region = applied.region;
    if (applied.category) params.category = applied.category;
    return (await api.get("/destinations", { params })).data.items;
  }, [applied]);

  const set = (k) => (e) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = () => setApplied(draft);
  const reset = () => { setDraft(EMPTY_FILTERS); setApplied(EMPTY_FILTERS); };
  const activeFilters = [draft.region, draft.category].filter(Boolean).length;
  const isFiltered = Object.values(applied).some(Boolean);

  const fetchWeather = (d) =>
    act(`w${d.id}`, async () => {
      try {
        const res = await getWeather(d.latitude, d.longitude);
        setWeather((prev) => ({ ...prev, [d.id]: res.data }));
      } catch {
        toast.error(`Weather lookup failed for ${d.name}.`);
      }
    });

  const handleDelete = async (d) => {
    const ok = await confirm({ title: `Delete ${d.name}?`, message: "The destination will be removed from the catalog and from any packages that include it.", confirmLabel: "Delete destination" });
    if (!ok) return;
    try {
      await api.delete(`/destinations/${d.id}`);
      toast.success("Destination deleted.");
      reload();
    } catch (err) {
      toast.error(errorMessage(err, "Failed to delete destination."));
    }
  };

  const columns = [
    {
      key: "place", header: "Destination", primary: true,
      render: (d) => (
        <div className="row">
          <Thumb src={d.imageUrl} alt={d.name} icon={MapPin} />
          <div style={{ minWidth: 0 }}>
            <div><strong>{d.name}</strong></div>
            <div className="cell-sub">{d.region}</div>
          </div>
        </div>
      ),
    },
    { key: "category", header: "Category", render: (d) => (d.category ? <Badge>{d.category}</Badge> : "—") },
    {
      key: "coords", header: "Coordinates",
      render: (d) => d.latitude != null && d.longitude != null
        ? <span className="mono muted" style={{ fontSize: "var(--fs-sm)" }}>{d.latitude.toFixed(4)}, {d.longitude.toFixed(4)}</span> : "—",
    },
    {
      key: "weather", header: "Weather",
      render: (d) => {
        const w = weather[d.id];
        if (w) {
          return w.available
            ? <Badge tone={w.isRainy ? "info" : "warning"} icon={w.isRainy ? CloudRain : Sun}>{w.temperature}°C</Badge>
            : <span className="muted">N/A</span>;
        }
        if (!d.latitude || !d.longitude) return <span className="muted">No coordinates</span>;
        return <Button size="sm" icon={Thermometer} loading={busy === `w${d.id}`} onClick={() => fetchWeather(d)}>Check</Button>;
      },
    },
    {
      key: "actions", actions: true,
      render: (d) => (
        <div className="row" style={{ justifyContent: "flex-end", gap: 4 }}>
          <Button size="sm" icon={Pencil} onClick={() => setEditing(d)}>Edit</Button>
          <IconButton icon={Trash2} label={`Delete ${d.name}`} size="sm" variant="soft-danger" onClick={() => handleDelete(d)} />
        </div>
      ),
    },
  ];

  const filters = (
    <>
      <Input aria-label="Region" placeholder="Region" value={draft.region} onChange={set("region")} />
      <Input aria-label="Category" placeholder="Category" value={draft.category} onChange={set("category")} />
    </>
  );

  return (
    <div className="page">
      <PageHeader title="Destinations" subtitle="Places travellers can visit. Coordinates power route maps and live weather." actions={<Button variant="primary" icon={Plus} onClick={() => setEditing("new")}>Add destination</Button>} />

      <Toolbar
        search={<SearchInput value={draft.search} onChange={(v) => setDraft((d) => ({ ...d, search: v }))} onEnter={apply} placeholder="Search destinations…" />}
        filters={filters}
        activeFilters={activeFilters}
        onApply={apply}
        onReset={reset}
      />

      {loading && !destinations ? (
        <Card><TableSkeleton /></Card>
      ) : error && !destinations ? (
        <Card><ErrorState text="Destinations could not be loaded." onRetry={reload} /></Card>
      ) : destinations.length === 0 ? (
        <Card>
          <EmptyState
            icon={MapPin}
            title={isFiltered ? "No destinations match your filters" : "No destinations yet"}
            text={isFiltered ? "Try removing a filter or searching for something else." : "Add your first destination to start building packages."}
            action={isFiltered ? <Button onClick={reset}>Clear filters</Button> : <Button variant="primary" icon={Plus} onClick={() => setEditing("new")}>Add destination</Button>}
          />
        </Card>
      ) : (
        <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          <DataTable columns={columns} rows={destinations} caption="Destinations" />
        </div>
      )}

      {editing && (
        <DestinationDrawer
          destination={editing === "new" ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={(isEdit) => { setEditing(null); toast.success(isEdit ? "Destination updated." : "Destination added."); reload(); }}
        />
      )}
    </div>
  );
}

function DestinationDrawer({ destination: dest, onClose, onSaved }) {
  const [form, setForm] = useState(() => dest ? {
    name: dest.name, region: dest.region, description: dest.description || "", category: dest.category || "",
    imageUrl: dest.imageUrl || "", latitude: dest.latitude ?? "", longitude: dest.longitude ?? "",
  } : EMPTY_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [imgOk, setImgOk] = useState(true);
  const f = (k) => ({ value: form[k], onChange: (e) => setForm({ ...form, [k]: e.target.value }) });

  const submit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setError("");
    const payload = {
      ...form,
      latitude: form.latitude === "" ? null : parseFloat(form.latitude),
      longitude: form.longitude === "" ? null : parseFloat(form.longitude),
    };
    try {
      if (dest) await api.put(`/destinations/${dest.id}`, payload);
      else await api.post("/destinations", payload);
      onSaved(!!dest);
    } catch (err) {
      setError(errorMessage(err, "Failed to save destination."));
      setSubmitting(false);
    }
  };

  return (
    <Drawer
      title={dest ? "Edit destination" : "Add destination"}
      onClose={onClose}
      footer={<><Button onClick={onClose}>Cancel</Button><Button type="submit" form="dest-form" variant="primary" loading={submitting}>{dest ? "Save changes" : "Add destination"}</Button></>}
    >
      <form id="dest-form" className="form-grid" onSubmit={submit}>
        {error && <Alert tone="error" className="span-all">{error}</Alert>}
        <Input label="Name" required {...f("name")} />
        <Input label="Region" required {...f("region")} />
        <Input label="Category" className="span-all" placeholder="e.g. Beach, Heritage, Wildlife" {...f("category")} />
        <Textarea label="Description" className="span-all" {...f("description")} />
        <Input label="Image URL" type="url" inputMode="url" className="span-all" placeholder="https://…" {...f("imageUrl")} onChange={(e) => { setImgOk(true); setForm({ ...form, imageUrl: e.target.value }); }} />
        {form.imageUrl && imgOk && (
          <img className="thumb thumb--lg" src={form.imageUrl} alt="Destination preview" onError={() => setImgOk(false)} style={{ gridColumn: "1 / -1", objectFit: "cover" }} />
        )}
        <Input label="Latitude" type="number" step="any" hint="e.g. 7.2906" {...f("latitude")} />
        <Input label="Longitude" type="number" step="any" hint="e.g. 80.6337" {...f("longitude")} />
      </form>
    </Drawer>
  );
}
