import { useEffect, useState } from "react";
import { CalendarCheck, CreditCard, Trash2, UserCheck, RefreshCw } from "lucide-react";
import api from "../services/api";
import {
  Alert, Badge, Button, DataTable, EmptyState, ErrorState, Menu, Modal, PageHeader, Select, Tabs,
  TableSkeleton, Card, useConfirm, useToast,
} from "../components/ui";
import { errorMessage, formatLKR, useAction, useRemote } from "../lib/hooks";


// `status` value returned by the API is an index into this array.
const STATUS_OPTIONS = ["Pending", "Confirmed", "Cancelled", "Ended", "OnGoing", "Rejected"];
const TABS = ["All", "Pending", "Confirmed", "OnGoing", "Ended", "Rejected", "Cancelled"].map((t) => ({ value: t, label: t === "OnGoing" ? "Ongoing" : t }));

const STATUS_TONE = {
  Pending: "warning", Confirmed: "info", OnGoing: "accent", Ended: "success", Cancelled: "neutral", Rejected: "danger",
};
const statusLabel = (s) => (typeof s === "number" ? STATUS_OPTIONS[s] : s);

export default function BookingsPage() {
  const [tab, setTab] = useState("Pending");
  const toast = useToast();
  const confirm = useConfirm();
  const [busy, act] = useAction();

  const { data: bookings, loading, error, reload } = useRemote(async () => {
    const params = { pageSize: 50 };
    if (tab !== "All") params.status = tab;
    return (await api.get("/bookings", { params })).data.items;
  }, [tab]);

  const changeStatus = (b, status) =>
    act(b.id, async () => {
      try {
        await api.put(`/bookings/${b.id}/status`, { status });
        toast.success(`Booking #${b.id} marked ${status}.`);
        reload();
      } catch (err) {
        toast.error(errorMessage(err, "Failed to update status."));
      }
    });

  const remove = async (b) => {
    const ok = await confirm({
      title: `Delete booking #${b.id}?`,
      message: "This permanently removes the booking and cannot be undone.",
      confirmLabel: "Delete booking",
    });
    if (!ok) return;
    await act(b.id, async () => {
      try {
        await api.delete(`/bookings/${b.id}`);
        toast.success("Booking deleted.");
        reload();
      } catch (err) {
        toast.error(errorMessage(err, "Failed to delete booking."));
      }
    });
  };

  const [assigning, setAssigning] = useState(null);

  const columns = [
    {
      key: "id", header: "Booking", primary: true,
      render: (b) => (
        <div>
          <div className="mono"><strong>#{b.id}</strong></div>
          <div className="cell-sub">{new Date(b.createdAt).toLocaleDateString()}</div>
        </div>
      ),
    },
    {
      key: "tourist", header: "Tourist",
      render: (b) => (
        <div>
          <div>{b.tourist?.name ?? `User #${b.touristId}`}</div>
          <div className="cell-sub">{b.tourist?.mobileNumber ?? b.tourist?.email ?? ""}</div>
        </div>
      ),
    },
    {
      key: "package", header: "Package",
      render: (b) => (
        <div>
          <div>{b.packageName ?? `Package #${b.packageId}`}</div>
          <div className="cell-sub">{b.groupSize ?? 1} {(b.groupSize ?? 1) === 1 ? "guest" : "guests"}</div>
        </div>
      ),
    },
    {
      key: "team", header: "Guide / Vehicle",
      render: (b) => (b.guideName || b.vehicleName ? (
        <div><div>{b.guideName ?? "—"}</div><div className="cell-sub">{b.vehicleName ?? "—"}</div></div>
      ) : <span className="muted">Unassigned</span>),
    },
    { key: "cost", header: "Total", render: (b) => <span className="mono">{formatLKR(b.totalPrice)}</span> },
    {
      key: "status", header: "Status",
      render: (b) => {
        const s = statusLabel(b.status);
        return (
          <div className="row row--wrap" style={{ gap: 6, justifyContent: "inherit" }}>
            <Badge tone={STATUS_TONE[s] ?? "neutral"} dot>{s === "OnGoing" ? "Ongoing" : s}</Badge>
            <Badge tone={b.isPaid ? "success" : "danger"}>{b.isPaid ? "Paid" : "Unpaid"}</Badge>
          </div>
        );
      },
    },
    {
      key: "actions", actions: true,
      render: (b) => {
        const s = statusLabel(b.status);
        const needsAssignment = s === "Pending" && b.packageId && !b.guideName && !b.vehicleName && b.isPaid;
        const awaitingPayment = s === "Pending" && b.packageId && !b.isPaid;
        return (
          <div className="row" style={{ justifyContent: "flex-end" }}>
            {needsAssignment && <Button size="sm" variant="primary" icon={UserCheck} onClick={() => setAssigning(b)}>Assign &amp; confirm</Button>}
            {awaitingPayment && <Badge tone="warning" icon={CreditCard}>Awaiting payment</Badge>}
            <Menu
              label={`Actions for booking ${b.id}`}
              items={[
                { heading: "Change status" },
                ...STATUS_OPTIONS.filter((x) => x !== s).map((x) => ({ label: x === "OnGoing" ? "Ongoing" : x, icon: RefreshCw, onClick: () => changeStatus(b, x) })),
                "separator",
                { label: "Delete booking", icon: Trash2, danger: true, onClick: () => remove(b) },
              ]}
            />
          </div>
        );
      },
    },
  ];

  return (
    <div className="page">
      <PageHeader title="Bookings" subtitle="Review incoming tours, assign a guide and vehicle once paid, and track each booking through to completion." />

      <div style={{ marginBottom: "var(--space-4)" }}>
        <Tabs label="Filter bookings by status" tabs={TABS} value={tab} onChange={setTab} />
      </div>

      {loading && !bookings ? (
        <Card><TableSkeleton /></Card>
      ) : error && !bookings ? (
        <Card><ErrorState text="Bookings could not be loaded." onRetry={reload} /></Card>
      ) : bookings.length === 0 ? (
        <Card>
          <EmptyState
            icon={CalendarCheck}
            title={tab === "All" ? "No bookings yet" : `No ${tab === "OnGoing" ? "ongoing" : tab.toLowerCase()} bookings`}
            text="New bookings from the mobile app will appear here."
          />
        </Card>
      ) : (
        <div style={{ opacity: loading || busy ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          <DataTable columns={columns} rows={bookings} caption="Bookings" />
        </div>
      )}

      {assigning && (
        <AssignModal
          booking={assigning}
          onClose={() => setAssigning(null)}
          onDone={() => { setAssigning(null); toast.success(`Tour confirmed for booking #${assigning.id}.`); reload(); }}
        />
      )}
    </div>
  );
}

function AssignModal({ booking, onClose, onDone }) {
  const [guides, setGuides] = useState([]);
  const [vehicles, setVehicles] = useState([]);
  const [loadingOptions, setLoadingOptions] = useState(true);
  const [guideId, setGuideId] = useState("");
  const [vehicleId, setVehicleId] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [g, v] = await Promise.all([
          api.get("/guides", { params: { available: true, pageSize: 100 } }),
          api.get("/vehicles", { params: { available: true, pageSize: 100 } }),
        ]);
        if (cancelled) return;
        setGuides(g.data.items ?? []);
        // Only offer vehicles big enough to seat the whole group.
        setVehicles((v.data.items ?? []).filter((x) => x.capacity >= (booking.groupSize || 1)));
      } catch {
        if (!cancelled) setError("Failed to load available guides/vehicles.");
      } finally {
        if (!cancelled) setLoadingOptions(false);
      }
    })();
    return () => { cancelled = true; };
  }, [booking]);

  const submit = async () => {
    if (!guideId || !vehicleId) { setError("Please select both a guide and a vehicle."); return; }
    setSubmitting(true);
    setError("");
    try {
      await api.post("/assignments/assign-confirm", { bookingId: booking.id, guideId: Number(guideId), vehicleId: Number(vehicleId) });
      onDone();
    } catch (err) {
      setError(errorMessage(err, "Failed to assign & confirm."));
      setSubmitting(false);
    }
  };

  return (
    <Modal
      title={`Assign team · Booking #${booking.id}`}
      description={`Group of ${booking.groupSize ?? 1} — only vehicles that seat everyone are listed.`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="success" loading={submitting} disabled={loadingOptions} onClick={submit}>Confirm tour</Button>
        </>
      }
    >
      <div className="stack">
        {error && <Alert tone="error">{error}</Alert>}
        <Select
          label="Guide"
          required
          disabled={loadingOptions}
          placeholder={loadingOptions ? "Loading guides…" : "Select a guide"}
          value={guideId}
          onChange={(e) => setGuideId(e.target.value)}
          hint={!loadingOptions && guides.length === 0 ? "No available guides right now." : undefined}
          options={guides.map((g) => ({ value: g.id, label: `${g.name ?? `Guide #${g.id}`} — ${g.region} (★ ${Number(g.rating ?? 0).toFixed(1)})` }))}
        />
        <Select
          label="Vehicle"
          required
          disabled={loadingOptions}
          placeholder={loadingOptions ? "Loading vehicles…" : "Select a vehicle"}
          value={vehicleId}
          onChange={(e) => setVehicleId(e.target.value)}
          hint={!loadingOptions && vehicles.length === 0 ? "No available vehicle seats this many people." : undefined}
          options={vehicles.map((v) => ({ value: v.id, label: `${v.name ?? v.type} — seats ${v.capacity} — ${v.region}` }))}
        />
      </div>
    </Modal>
  );
}
