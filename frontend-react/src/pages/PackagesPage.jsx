import { useState } from "react";
import { Hotel, MapPin, Map as MapIcon, Package as PackageIcon, Pencil, Plus, SlidersHorizontal, Trash2, X } from "lucide-react";
import api, { assetUrl } from "../services/api";
import {
  Alert, Badge, Button, Card, DataTable, Drawer, Thumb, EmptyState, ErrorState, IconButton, Input, Menu, PageHeader, Select, Switch,
  TableSkeleton, Textarea, useConfirm, useToast,
} from "../components/ui";
import { errorMessage, formatLKR, useAction, useRemote } from "../lib/hooks";

const EMPTY_FORM = { name: "", description: "", imageUrl: "", basePrice: "", durationDays: "", maxPeople: "4", isPublished: false };

// Builds a Google Maps directions link from the package's destinations (already ordered
// by DayNumber from the backend).
function routeUrl(pkg) {
  const points = (pkg.destinations ?? []).filter((d) => d.latitude != null && d.longitude != null);
  if (points.length === 0) return null;
  const at = (p) => `${p.latitude},${p.longitude}`;
  const waypoints = points.length > 2 ? points.slice(1, -1).map(at).join("|") : "";
  return `https://www.google.com/maps/dir/?api=1&origin=${at(points[0])}&destination=${at(points[points.length - 1])}` +
    (waypoints ? `&waypoints=${waypoints}` : "") + "&travelmode=driving";
}

export default function PackagesPage() {
  const [editing, setEditing] = useState(null); // null | "new" | package
  const [managingId, setManagingId] = useState(null);
  const [busy, act] = useAction();
  const toast = useToast();
  const confirm = useConfirm();

  const { data: packages, loading, error, reload } = useRemote(async () => (await api.get("/packages", { params: { pageSize: 50 } })).data.items, []);
  const { data: picker } = useRemote(async () => {
    const [d, h] = await Promise.all([
      api.get("/destinations", { params: { pageSize: 200 } }),
      api.get("/hotels", { params: { pageSize: 200 } }),
    ]);
    return { destinations: d.data.items ?? [], hotels: h.data.items ?? [] };
  }, []);

  const managing = packages?.find((p) => p.id === managingId);

  const togglePublish = (p) =>
    act(`pub${p.id}`, async () => {
      try {
        await api.put(`/packages/${p.id}`, {
          name: p.name, description: p.description, imageUrl: p.imageUrl, basePrice: p.basePrice, durationDays: p.durationDays, maxPeople: p.maxPeople,
          suggestedGuideId: null, suggestedVehicleId: null, isPublished: !p.isPublished,
        });
        toast.success(p.isPublished ? `${p.name} moved to drafts.` : `${p.name} is now published.`);
        reload();
      } catch (err) {
        toast.error(errorMessage(err, "Failed to update publish status."));
      }
    });

  const handleDelete = async (p) => {
    const ok = await confirm({ title: `Delete ${p.name}?`, message: "Existing bookings keep their record, but the package disappears from the catalog.", confirmLabel: "Delete package" });
    if (!ok) return;
    try {
      await api.delete(`/packages/${p.id}`);
      toast.success("Package deleted.");
      reload();
    } catch (err) {
      toast.error(errorMessage(err, "Failed to delete package."));
    }
  };

  const viewRoute = (p) => {
    const url = routeUrl(p);
    if (!url) { toast.info("This package has no destinations with coordinates yet."); return; }
    window.open(url, "_blank", "noopener");
  };

  const columns = [
    {
      key: "name", header: "Package", primary: true,
      render: (p) => (
        <div className="row">
          <Thumb src={p.imageUrl} alt={p.name} icon={PackageIcon} />
          <div style={{ minWidth: 0 }}>
            <div><strong>{p.name}</strong></div>
            <div className="cell-sub">{p.durationDays} days · up to {p.maxPeople} people</div>
          </div>
        </div>
      ),
    },
    { key: "price", header: "Base price", render: (p) => <span className="mono">{formatLKR(p.basePrice)}</span> },
    { key: "stops", header: "Stops", render: (p) => `${p.destinations?.length ?? 0} destinations · ${p.hotels?.length ?? 0} hotels` },
    {
      key: "published", header: "Published",
      render: (p) => (
        <Switch
          checked={!!p.isPublished}
          disabled={busy === `pub${p.id}`}
          onChange={() => togglePublish(p)}
          label={<Badge tone={p.isPublished ? "success" : "neutral"} dot>{p.isPublished ? "Published" : "Draft"}</Badge>}
        />
      ),
    },
    {
      key: "actions", actions: true,
      render: (p) => (
        <div className="row" style={{ justifyContent: "flex-end", gap: 4 }}>
          <Button size="sm" icon={SlidersHorizontal} onClick={() => setManagingId(p.id)}>Manage</Button>
          <Menu
            label={`More actions for ${p.name}`}
            items={[
              { label: "Edit details", icon: Pencil, onClick: () => setEditing(p) },
              { label: "View route in Maps", icon: MapIcon, onClick: () => viewRoute(p) },
              "separator",
              { label: "Delete package", icon: Trash2, danger: true, onClick: () => handleDelete(p) },
            ]}
          />
        </div>
      ),
    },
  ];

  return (
    <div className="page">
      <PageHeader title="Packages" subtitle="Curated tours tourists can book. Publish a package once its route and hotels are set." actions={<Button variant="primary" icon={Plus} onClick={() => setEditing("new")}>Add package</Button>} />

      {loading && !packages ? (
        <Card><TableSkeleton /></Card>
      ) : error && !packages ? (
        <Card><ErrorState text="Packages could not be loaded." onRetry={reload} /></Card>
      ) : packages.length === 0 ? (
        <Card><EmptyState icon={PackageIcon} title="No packages yet" text="Create a package, then add destinations and hotels to shape the tour." action={<Button variant="primary" icon={Plus} onClick={() => setEditing("new")}>Add package</Button>} /></Card>
      ) : (
        <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          <DataTable columns={columns} rows={packages} caption="Packages" />
        </div>
      )}

      {editing && (
        <PackageDrawer
          pkg={editing === "new" ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={(isEdit) => { setEditing(null); toast.success(isEdit ? "Package updated." : "Package created."); reload(); }}
        />
      )}

      {managing && <ManageDrawer pkg={managing} picker={picker} onClose={() => setManagingId(null)} onChanged={reload} onRoute={() => viewRoute(managing)} />}
    </div>
  );
}

function PackageDrawer({ pkg, onClose, onSaved }) {
  const [form, setForm] = useState(() => pkg ? {
    name: pkg.name, description: pkg.description || "", imageUrl: pkg.imageUrl || "", basePrice: pkg.basePrice, durationDays: pkg.durationDays,
    maxPeople: pkg.maxPeople ?? 4, isPublished: pkg.isPublished,
  } : EMPTY_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [uploading, setUploading] = useState(false);
  const [imgOk, setImgOk] = useState(true);
  const f = (k) => ({ value: form[k], onChange: (e) => setForm({ ...form, [k]: e.target.value }) });

  const uploadCover = async (file) => {
    if (!file) return;
    setUploading(true);
    setError("");
    try {
      const data = new FormData();
      data.append("file", file);
      const res = await api.post("/packages/upload-image", data);
      setImgOk(true);
      setForm((cur) => ({ ...cur, imageUrl: res.data.imageUrl }));
    } catch (err) {
      setError(errorMessage(err, "Couldn't upload the photo."));
    } finally {
      setUploading(false);
    }
  };

  const submit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setError("");
    const payload = {
      ...form,
      basePrice: parseFloat(form.basePrice),
      durationDays: parseInt(form.durationDays),
      maxPeople: parseInt(form.maxPeople) || 4,
      suggestedGuideId: null,
      suggestedVehicleId: null,
    };
    try {
      if (pkg) await api.put(`/packages/${pkg.id}`, payload);
      else await api.post("/packages", payload);
      onSaved(!!pkg);
    } catch (err) {
      setError(errorMessage(err, "Failed to save package."));
      setSubmitting(false);
    }
  };

  return (
    <Drawer
      title={pkg ? "Edit package" : "Add package"}
      onClose={onClose}
      footer={<><Button onClick={onClose}>Cancel</Button><Button type="submit" form="pkg-form" variant="primary" loading={submitting}>{pkg ? "Save changes" : "Create package"}</Button></>}
    >
      <form id="pkg-form" className="form-grid form-grid--3" onSubmit={submit}>
        {error && <Alert tone="error" className="span-all">{error}</Alert>}
        <Input label="Name" required className="span-all" {...f("name")} />
        <Textarea label="Description" className="span-all" {...f("description")} />
        <div className="span-all stack" style={{ gap: "var(--space-2)" }}>
          <span className="field__label">Cover photo</span>
          {form.imageUrl && imgOk && (
            <img className="thumb thumb--lg" src={assetUrl(form.imageUrl)} alt="Cover preview" onError={() => setImgOk(false)} style={{ objectFit: "cover" }} />
          )}
          <div className="row row--wrap">
            <label className="btn" style={{ cursor: "pointer" }}>
              {uploading ? "Uploading…" : form.imageUrl ? "Replace photo" : "Upload photo"}
              <input type="file" accept="image/jpeg,image/png,image/webp" hidden disabled={uploading} onChange={(e) => uploadCover(e.target.files?.[0])} />
            </label>
            {form.imageUrl && <Button variant="ghost" onClick={() => setForm({ ...form, imageUrl: "" })}>Remove</Button>}
          </div>
          <Input label="…or paste an image URL" type="text" inputMode="url" placeholder="https://…" value={form.imageUrl} onChange={(e) => { setImgOk(true); setForm({ ...form, imageUrl: e.target.value }); }} />
        </div>
        <Input label="Base price (LKR)" type="number" min="0" required {...f("basePrice")} />
        <Input label="Duration (days)" type="number" min="1" required {...f("durationDays")} />
        <Input label="Max people" type="number" min="1" required {...f("maxPeople")} />
        <div className="span-all">
          <Switch checked={form.isPublished} onChange={(v) => setForm({ ...form, isPublished: v })} label="Published — visible to tourists" />
        </div>
        <Alert className="span-all">
          Guides and vehicles aren't pre-assigned to a package. Once a tourist books and pays, assign them to that booking from the Bookings page.
        </Alert>
      </form>
    </Drawer>
  );
}

function ManageDrawer({ pkg, picker, onClose, onChanged, onRoute }) {
  const toast = useToast();
  const [destId, setDestId] = useState("");
  const [destDay, setDestDay] = useState("1");
  const [hotelId, setHotelId] = useState("");
  const [busy, act] = useAction();

  const run = (key, fn, failMsg) => act(key, async () => {
    try { await fn(); onChanged(); } catch (err) { toast.error(errorMessage(err, failMsg)); }
  });

  const addDestination = () => !destId ? null : run("addDest", async () => {
    await api.post(`/packages/${pkg.id}/destinations`, { destinationId: Number(destId), dayNumber: parseInt(destDay) || 1 });
    setDestId(""); setDestDay("1");
  }, "Failed to add destination.");
  const removeDestination = (d) => run(`rd${d.id}`, () => api.delete(`/packages/${pkg.id}/destinations/${d.id}`), "Failed to remove destination.");
  const addHotel = () => !hotelId ? null : run("addHotel", async () => {
    await api.post(`/packages/${pkg.id}/hotels`, { hotelId: Number(hotelId) });
    setHotelId("");
  }, "Failed to add hotel.");
  const removeHotel = (h) => run(`rh${h.id}`, () => api.delete(`/packages/${pkg.id}/hotels/${h.id}`), "Failed to remove hotel.");

  return (
    <Drawer
      title={pkg.name}
      description="Build the route and choose where guests stay."
      onClose={onClose}
      footer={<><Button icon={MapIcon} onClick={onRoute}>View route</Button><Button variant="primary" onClick={onClose}>Done</Button></>}
    >
      <div className="stack" style={{ gap: "var(--space-6)" }}>
        <section>
          <h3 className="section-title"><MapPin size={17} aria-hidden="true" /> Destinations &amp; route</h3>
          {pkg.destinations?.length ? (
            <ol className="timeline">
              {pkg.destinations.map((d) => (
                <li key={d.id}>
                  <div className="row row--between">
                    <div><strong>Day {d.dayNumber}</strong> · {d.name} <span className="muted">({d.region})</span></div>
                    <IconButton icon={X} label={`Remove ${d.name}`} size="sm" disabled={busy === `rd${d.id}`} onClick={() => removeDestination(d)} />
                  </div>
                </li>
              ))}
            </ol>
          ) : <p className="muted" style={{ marginBottom: "var(--space-3)" }}>No destinations added yet.</p>}
          <div className="row row--wrap" style={{ alignItems: "flex-end" }}>
            <Select label="Destination" className="search" placeholder="Select destination…" value={destId} onChange={(e) => setDestId(e.target.value)}
              options={(picker?.destinations ?? []).map((d) => ({ value: d.id, label: `${d.name} (${d.region})` }))} />
            <Input label="Day" type="number" min="1" value={destDay} onChange={(e) => setDestDay(e.target.value)} style={{ width: 80 }} />
            <Button icon={Plus} disabled={!destId} loading={busy === "addDest"} onClick={addDestination}>Add</Button>
          </div>
        </section>

        <section>
          <h3 className="section-title"><Hotel size={17} aria-hidden="true" /> Hotels</h3>
          {pkg.hotels?.length ? (
            <ul className="stack" style={{ listStyle: "none", padding: 0, margin: "0 0 var(--space-3)", gap: "var(--space-2)" }}>
              {pkg.hotels.map((h) => (
                <li key={h.id} className="panel-soft row row--between" style={{ padding: "var(--space-2) var(--space-3)" }}>
                  <div style={{ minWidth: 0 }}>
                    <div className="truncate"><strong>{h.name}</strong> <span className="muted">({h.region})</span></div>
                    <div className="cell-sub">{formatLKR(h.pricePerNight)} / night</div>
                  </div>
                  <IconButton icon={X} label={`Remove ${h.name}`} size="sm" disabled={busy === `rh${h.id}`} onClick={() => removeHotel(h)} />
                </li>
              ))}
            </ul>
          ) : <p className="muted" style={{ marginBottom: "var(--space-3)" }}>No hotels added yet.</p>}
          <div className="row row--wrap" style={{ alignItems: "flex-end" }}>
            <Select label="Hotel" className="search" placeholder="Select hotel…" value={hotelId} onChange={(e) => setHotelId(e.target.value)}
              options={(picker?.hotels ?? []).map((h) => ({ value: h.id, label: `${h.name} (${h.region})` }))} />
            <Button icon={Plus} disabled={!hotelId} loading={busy === "addHotel"} onClick={addHotel}>Add</Button>
          </div>
        </section>
      </div>
    </Drawer>
  );
}
