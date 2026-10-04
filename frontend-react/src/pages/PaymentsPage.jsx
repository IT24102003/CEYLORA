import { useState } from "react";
import { ChevronLeft, ChevronRight, CreditCard, Wallet } from "lucide-react";
import api from "../services/api";
import {
  Badge, Button, Card, DataTable, EmptyState, ErrorState, PageHeader, SearchInput, Select, StatCard,
  TableSkeleton, Toolbar,
} from "../components/ui";
import { formatLKR, useRemote } from "../lib/hooks";

const EMPTY = { search: "", status: "" };
const PAGE_SIZE = 20;

const STATUS_TONE = { Success: "success", Pending: "warning", Failed: "danger" };

export default function PaymentsPage() {
  const [draft, setDraft] = useState(EMPTY);
  const [applied, setApplied] = useState(EMPTY);
  const [page, setPage] = useState(1);

  const { data, loading, error, reload } = useRemote(async () => {
    const params = { page, pageSize: PAGE_SIZE };
    if (applied.search) params.search = applied.search;
    if (applied.status) params.status = applied.status;
    return (await api.get("/payments", { params })).data;
  }, [applied, page]);

  const set = (k) => (e) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = () => { setApplied(draft); setPage(1); };
  const reset = () => { setDraft(EMPTY); setApplied(EMPTY); setPage(1); };
  const activeFilters = [draft.status].filter(Boolean).length;
  const isFiltered = Object.values(applied).some(Boolean);

  const payments = data?.items ?? [];
  const totalCount = data?.totalCount ?? 0;
  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));

  const columns = [
    {
      key: "booking", header: "Booking", primary: true,
      render: (p) => (
        <div>
          <div><strong>#{p.bookingId}</strong> {p.tripName ? `· ${p.tripName}` : ""}</div>
          <div className="cell-sub">{p.touristName} · {p.touristEmail}</div>
        </div>
      ),
    },
    { key: "amount", header: "Amount", render: (p) => <span className="mono">{formatLKR(p.amount)}</span> },
    { key: "status", header: "Status", render: (p) => <Badge tone={STATUS_TONE[p.status] ?? "neutral"} dot>{p.status}</Badge> },
    { key: "provider", header: "Provider" },
    { key: "createdAt", header: "Date", render: (p) => new Date(p.createdAt).toLocaleString() },
  ];

  const filters = (
    <Select
      aria-label="Status"
      value={draft.status}
      onChange={set("status")}
      placeholder="Any status"
      options={[
        { value: "Success", label: "Success" },
        { value: "Pending", label: "Pending" },
        { value: "Failed", label: "Failed" },
      ]}
    />
  );

  return (
    <div className="page">
      <PageHeader title="Payments" subtitle="Every payment recorded across all bookings." />

      <div className="stat-grid">
        <StatCard label="Total revenue (successful payments)" value={formatLKR(data?.totalRevenue ?? 0)} icon={Wallet} tone="success" />
        <StatCard label="Payments on this page" value={payments.length} note={totalCount ? `${totalCount} total` : undefined} icon={CreditCard} />
      </div>

      <Toolbar
        search={<SearchInput value={draft.search} onChange={(v) => setDraft((d) => ({ ...d, search: v }))} onEnter={apply} placeholder="Search by tourist name, email or booking ID…" />}
        filters={filters}
        activeFilters={activeFilters}
        onApply={apply}
        onReset={reset}
      />

      {loading && !data ? (
        <Card><TableSkeleton /></Card>
      ) : error && !data ? (
        <Card><ErrorState text="Payments could not be loaded." onRetry={reload} /></Card>
      ) : payments.length === 0 ? (
        <Card>
          <EmptyState
            icon={CreditCard}
            title={isFiltered ? "No payments match your filters" : "No payments yet"}
            text={isFiltered ? "Try removing a filter or searching for something else." : "Payments will appear here once tourists start paying for bookings."}
            action={isFiltered && <Button onClick={reset}>Clear filters</Button>}
          />
        </Card>
      ) : (
        <>
          <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
            <DataTable columns={columns} rows={payments} caption="Payments" />
          </div>
          {totalPages > 1 && (
            <div className="row row--between" style={{ marginTop: 12 }}>
              <span className="muted" style={{ fontSize: "var(--fs-sm)" }}>Page {page} of {totalPages}</span>
              <div className="row">
                <Button icon={ChevronLeft} disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Previous</Button>
                <Button icon={ChevronRight} disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>Next</Button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
