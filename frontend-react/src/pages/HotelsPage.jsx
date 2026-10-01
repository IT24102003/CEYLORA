import { useState } from "react";
import { Hotel, Pencil, Plus, Star, Trash2 } from "lucide-react";
import api from "../services/api";
import {
  Button, Card, DataTable, Drawer, EmptyState, ErrorState, IconButton, Input, PageHeader, SearchInput, Select,
  TableSkeleton, Textarea, Thumb, Toolbar, Alert, useConfirm, useToast,
} from "../components/ui";
import { errorMessage, formatLKR, useRemote } from "../lib/hooks";

const EMPTY_FORM = { name: "", region: "", address: "", starRating: "", pricePerNight: "", roomsAvailable: "", description: "", imageUrl: "" };
const EMPTY_FILTERS = { search: "", region: "", minStars: "" };

export default function HotelsPage() {
  const [draft, setDraft] = useState(EMPTY_FILTERS);
  const [applied, setApplied] = useState(EMPTY_FILTERS);
  const [editing, setEditing] = useState(null); // null | "new" | hotel
  const toast = useToast();
  const confirm = useConfirm();

  const { data: hotels, loading, error, reload } = useRemote(async () => {
    const params = { pageSize: 50 };
    if (applied.search) params.search = applied.search;
    if (applied.region) params.region = applied.region;
    if (applied.minStars) params.minStars = applied.minStars;
    return (await api.get("/hotels", { params })).data.items;
  }, [applied]);

  const set = (k) => (e) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = () => setApplied(draft);
  const reset = () => { setDraft(EMPTY_FILTERS); setApplied(EMPTY_FILTERS); };
  const activeFilters = [draft.region, draft.minStars].filter(Boolean).length;
  const isFiltered = Object.values(applied).some(Boolean);

  const handleDelete = async (h) => {
    const ok = await confirm({ title: `Delete ${h.name}?`, message: "The hotel will be removed from the catalog and from any packages using it.", confirmLabel: "Delete hotel" });
    if (!ok) return;
    try {
      await api.delete(`/hotels/${h.id}`);
      toast.success("Hotel deleted.");
      reload();
    } catch (err) {
      toast.error(errorMessage(err, "Failed to delete hotel."));
    }
  };

  const columns = [
    {
      key: "hotel", header: "Hotel", primary: true,
      render: (h) => (
        <div className="row">
          <Thumb src={h.imageUrl} alt={h.name} icon={Hotel} />
          <div style={{ minWidth: 0 }}>
            <div><strong>{h.name}</strong></div>
            <div className="cell-sub">{h.region}</div>
          </div>
        </div>
      ),
    },
    { key: "stars", header: "Stars", render: (h) => <span className="row" style={{ gap: 4 }}><Star size={14} fill="currentColor" style={{ color: "var(--c-warning)" }} aria-hidden="true" />{h.starRating}</span> },
    { key: "price", header: "Per night", render: (h) => <span className="mono">{formatLKR(h.pricePerNight)}</span> },
    { key: "rooms", header: "Rooms", render: (h) => h.roomsAvailable },
    {
      key: "actions", actions: true,
      render: (h) => (
        <div className="row" style={{ justifyContent: "flex-end", gap: 4 }}>
          <Button size="sm" icon={Pencil} onClick={() => setEditing(h)}>Edit</Button>
          <IconButton icon={Trash2} label={`Delete ${h.name}`} size="sm" variant="soft-danger" onClick={() => handleDelete(h)} />
        </div>
      ),
    },
  ];

  const filters = (
    <>
      <Input aria-label="Region" placeholder="Region" value={draft.region} onChange={set("region")} />
      <Select
        aria-label="Minimum stars" value={draft.minStars} onChange={set("minStars")} placeholder="Any star rating"
        options={[1, 2, 3, 4].map((n) => ({ value: n, label: `${n}★ and up` })).concat({ value: 5, label: "5★ only" })}
      />
    </>
  );

  return (
    <div className="page">
      <PageHeader title="Hotels" subtitle="Accommodation that can be attached to travel packages." actions={<Button variant="primary" icon={Plus} onClick={() => setEditing("new")}>Add hotel</Button>} />

      <Toolbar
        search={<SearchInput value={draft.search} onChange={(v) => setDraft((d) => ({ ...d, search: v }))} onEnter={apply} placeholder="Search hotels…" />}
        filters={filters}
        activeFilters={activeFilters}
        onApply={apply}
        onReset={reset}
      />

      {loading && !hotels ? (
        <Card><TableSkeleton /></Card>
      ) : error && !hotels ? (
        <Card><ErrorState text="Hotels could not be loaded." onRetry={reload} /></Card>
      ) : hotels.length === 0 ? (
        <Card>
          <EmptyState
            icon={Hotel}
            title={isFiltered ? "No hotels match your filters" : "No hotels yet"}
            text={isFiltered ? "Try removing a filter or searching for something else." : "Add your first hotel so it can be included in packages."}
            action={isFiltered ? <Button onClick={reset}>Clear filters</Button> : <Button variant="primary" icon={Plus} onClick={() => setEditing("new")}>Add hotel</Button>}
          />
        </Card>
      ) : (
        <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          <DataTable columns={columns} rows={hotels} caption="Hotels" />
        </div>
      )}

      {editing && (
        <HotelDrawer
          hotel={editing === "new" ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={(isEdit) => { setEditing(null); toast.success(isEdit ? "Hotel updated." : "Hotel added."); reload(); }}
        />
      )}
    </div>
  );
}

function HotelDrawer({ hotel, onClose, onSaved }) {
  const [form, setForm] = useState(() => hotel ? {
    name: hotel.name, region: hotel.region, address: hotel.address || "", starRating: hotel.starRating,
    pricePerNight: hotel.pricePerNight, roomsAvailable: hotel.roomsAvailable, description: hotel.description || "", imageUrl: hotel.imageUrl || "",
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
      starRating: parseInt(form.starRating),
      pricePerNight: parseFloat(form.pricePerNight),
      roomsAvailable: parseInt(form.roomsAvailable),
    };
    try {
      if (hotel) await api.put(`/hotels/${hotel.id}`, payload);
      else await api.post("/hotels", payload);
      onSaved(!!hotel);
    } catch (err) {
      setError(errorMessage(err, "Failed to save hotel."));
      setSubmitting(false);
    }
  };

  return (
    <Drawer
      title={hotel ? "Edit hotel" : "Add hotel"}
      onClose={onClose}
      footer={<><Button onClick={onClose}>Cancel</Button><Button type="submit" form="hotel-form" variant="primary" loading={submitting}>{hotel ? "Save changes" : "Add hotel"}</Button></>}
    >
      <form id="hotel-form" className="form-grid" onSubmit={submit}>
        {error && <Alert tone="error" className="span-all">{error}</Alert>}
        <Input label="Name" required {...f("name")} />
        <Input label="Region" required {...f("region")} />
        <Input label="Address" className="span-all" {...f("address")} />
        <Input label="Star rating" type="number" min="1" max="5" required hint="1 – 5" {...f("starRating")} />
        <Input label="Price per night (LKR)" type="number" min="0" required {...f("pricePerNight")} />
        <Input label="Rooms available" type="number" min="0" required {...f("roomsAvailable")} />
        <Input label="Image URL" type="url" inputMode="url" className="span-all" placeholder="https://…" {...f("imageUrl")} onChange={(e) => { setImgOk(true); setForm({ ...form, imageUrl: e.target.value }); }} />
        {form.imageUrl && imgOk && (
          <img className="thumb thumb--lg span-all" src={form.imageUrl} alt="Hotel preview" onError={() => setImgOk(false)} style={{ gridColumn: "1 / -1", objectFit: "cover" }} />
        )}
        <Textarea label="Description" className="span-all" {...f("description")} />
      </form>
    </Drawer>
  );
}
