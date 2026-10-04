import { useState } from "react";
import { Car, Trash2 } from "lucide-react";
import api from "../services/api";
import {
  Badge, Button, Card, DataTable, EmptyState, ErrorState, IconButton, Input, PageHeader, SearchInput, Select,
  TableSkeleton, Thumb, Toolbar, useConfirm, useToast,
} from "../components/ui";
import { errorMessage, useRemote } from "../lib/hooks";

const EMPTY = { search: "", region: "", type: "", available: "" };

export default function VehiclesPage() {
  const [draft, setDraft] = useState(EMPTY);
  const [applied, setApplied] = useState(EMPTY);
  const toast = useToast();
  const confirm = useConfirm();

  const { data: vehicles, loading, error, reload } = useRemote(async () => {
    const params = { pageSize: 50 };
    if (applied.search) params.search = applied.search;
    if (applied.region) params.region = applied.region;
    if (applied.type) params.type = applied.type;
    if (applied.available) params.available = applied.available;
    return (await api.get("/vehicles", { params })).data.items;
  }, [applied]);

  const set = (k) => (e) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = () => setApplied(draft);
  const reset = () => { setDraft(EMPTY); setApplied(EMPTY); };
  const activeFilters = [draft.region, draft.type, draft.available].filter(Boolean).length;
  const isFiltered = Object.values(applied).some(Boolean);

  const handleDelete = async (v) => {
    const ok = await confirm({ title: `Delete ${v.name ?? v.type}?`, message: "This vehicle will be removed from the fleet and can no longer be assigned to bookings.", confirmLabel: "Delete vehicle" });
    if (!ok) return;
    try {
      await api.delete(`/vehicles/${v.id}`);
      toast.success("Vehicle deleted.");
      reload();
    } catch (err) {
      toast.error(errorMessage(err, "Failed to delete vehicle."));
    }
  };

  const columns = [
    {
      key: "vehicle", header: "Vehicle", primary: true,
      render: (v) => {
        const cover = v.images?.find((i) => i.isCover) ?? v.images?.[0];
        return (
          <div className="row">
            <Thumb src={cover?.imageUrl} alt={v.name ?? v.type} icon={Car} />
            <div style={{ minWidth: 0 }}>
              <div><strong>{v.name ?? v.type}</strong></div>
              <div className="cell-sub">{v.type} · #{v.id}</div>
            </div>
          </div>
        );
      },
    },
    {
      key: "owner", header: "Owner",
      render: (v) => (
        <div>
          <div>{v.ownerName ?? "—"}</div>
          <div className="cell-sub">{[v.ownerCountry, v.ownerPhone].filter(Boolean).join(" · ")}</div>
        </div>
      ),
    },
    { key: "capacity", header: "Seats", render: (v) => v.capacity },
    { key: "region", header: "Region" },
    { key: "pricePerKm", header: "LKR / km", render: (v) => <span className="mono">{v.pricePerKm}</span> },
    { key: "available", header: "Status", render: (v) => <Badge tone={v.isAvailable ? "success" : "neutral"} dot>{v.isAvailable ? "Available" : "Unavailable"}</Badge> },
    { key: "actions", actions: true, render: (v) => <IconButton icon={Trash2} label={`Delete ${v.name ?? v.type}`} size="sm" variant="soft-danger" onClick={() => handleDelete(v)} /> },
  ];

  const filters = (
    <>
      <Input aria-label="Region" placeholder="Region" value={draft.region} onChange={set("region")} />
      <Input aria-label="Type" placeholder="Type" value={draft.type} onChange={set("type")} />
      <Select aria-label="Availability" value={draft.available} onChange={set("available")} placeholder="Any availability" options={[{ value: "true", label: "Available only" }, { value: "false", label: "Unavailable only" }]} />
    </>
  );

  return (
    <div className="page">
      <PageHeader title="Vehicles" subtitle="The registered fleet that can be assigned to confirmed tours." />

      <Toolbar
        search={<SearchInput value={draft.search} onChange={(v) => setDraft((d) => ({ ...d, search: v }))} onEnter={apply} placeholder="Search by type or region…" />}
        filters={filters}
        activeFilters={activeFilters}
        onApply={apply}
        onReset={reset}
      />

      {loading && !vehicles ? (
        <Card><TableSkeleton /></Card>
      ) : error && !vehicles ? (
        <Card><ErrorState text="Vehicles could not be loaded." onRetry={reload} /></Card>
      ) : vehicles.length === 0 ? (
        <Card>
          <EmptyState
            icon={Car}
            title={isFiltered ? "No vehicles match your filters" : "No vehicles yet"}
            text={isFiltered ? "Try removing a filter or searching for something else." : "Vehicles appear here once owners register them in the mobile app."}
            action={isFiltered && <Button onClick={reset}>Clear filters</Button>}
          />
        </Card>
      ) : (
        <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          <DataTable columns={columns} rows={vehicles} caption="Vehicles" />
        </div>
      )}
    </div>
  );
}
