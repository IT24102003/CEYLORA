import { useState } from "react";
import { Trash2, Users as UsersIcon } from "lucide-react";
import api from "../services/api";
import {
  Avatar, Badge, Card, DataTable, EmptyState, ErrorState, IconButton, PageHeader, SearchInput, Select,
  TableSkeleton, Toolbar, useConfirm, useToast,
} from "../components/ui";
import { errorMessage, useRemote } from "../lib/hooks";

const EMPTY = { search: "", role: "" };

const ROLE_TONE = { Admin: "accent", Guide: "info", VehicleOwner: "warning", Tourist: "neutral" };

export default function UsersPage() {
  const [draft, setDraft] = useState(EMPTY);
  const [applied, setApplied] = useState(EMPTY);
  const toast = useToast();
  const confirm = useConfirm();

  const { data: users, loading, error, reload } = useRemote(async () => {
    const params = {};
    if (applied.search) params.search = applied.search;
    if (applied.role) params.role = applied.role;
    return (await api.get("/users", { params })).data;
  }, [applied]);

  const set = (k) => (e) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = () => setApplied(draft);
  const reset = () => { setDraft(EMPTY); setApplied(EMPTY); };
  const activeFilters = [draft.role].filter(Boolean).length;
  const isFiltered = Object.values(applied).some(Boolean);

  const handleDelete = async (u) => {
    const ok = await confirm({
      title: `Delete ${u.name}?`,
      message: "This account will be permanently removed. Accounts with bookings on record, or the last remaining Admin, can't be deleted.",
      confirmLabel: "Delete account",
    });
    if (!ok) return;
    try {
      await api.delete(`/users/${u.id}`);
      toast.success("User deleted.");
      reload();
    } catch (err) {
      toast.error(errorMessage(err, "Failed to delete user."));
    }
  };

  const columns = [
    {
      key: "user", header: "User", primary: true,
      render: (u) => (
        <div className="row">
          <Avatar name={u.name} src={u.profilePictureUrl} />
          <div style={{ minWidth: 0 }}>
            <div><strong>{u.name}</strong></div>
            <div className="cell-sub">{u.email}</div>
          </div>
        </div>
      ),
    },
    { key: "role", header: "Role", render: (u) => <Badge tone={ROLE_TONE[u.role] ?? "neutral"}>{u.role}</Badge> },
    {
      key: "profile", header: "Profile",
      render: (u) => {
        if (u.role === "Guide") return <Badge tone={u.hasGuideProfile ? "success" : "warning"} dot>{u.hasGuideProfile ? "Linked" : "Not linked"}</Badge>;
        if (u.role === "VehicleOwner") return <Badge tone={u.hasVehicleOwnerProfile ? "success" : "warning"} dot>{u.hasVehicleOwnerProfile ? "Linked" : "Not linked"}</Badge>;
        return <span className="muted">—</span>;
      },
    },
    { key: "country", header: "Country", render: (u) => u.country ?? "—" },
    { key: "mobileNumber", header: "Mobile", render: (u) => u.mobileNumber ?? "—" },
    { key: "createdAt", header: "Joined", render: (u) => new Date(u.createdAt).toLocaleDateString() },
    { key: "actions", actions: true, render: (u) => <IconButton icon={Trash2} label={`Delete ${u.name}`} size="sm" variant="soft-danger" onClick={() => handleDelete(u)} /> },
  ];

  const filters = (
    <Select
      aria-label="Role"
      value={draft.role}
      onChange={set("role")}
      placeholder="Any role"
      options={[
        { value: "Tourist", label: "Tourist" },
        { value: "Guide", label: "Guide" },
        { value: "VehicleOwner", label: "Vehicle owner" },
        { value: "Admin", label: "Admin" },
      ]}
    />
  );

  return (
    <div className="page">
      <PageHeader title="Users" subtitle="Every account registered on CEYLORA — tourists, guides, vehicle owners and admins." />

      <Toolbar
        search={<SearchInput value={draft.search} onChange={(v) => setDraft((d) => ({ ...d, search: v }))} onEnter={apply} placeholder="Search by name or email…" />}
        filters={filters}
        activeFilters={activeFilters}
        onApply={apply}
        onReset={reset}
      />

      {loading && !users ? (
        <Card><TableSkeleton /></Card>
      ) : error && !users ? (
        <Card><ErrorState text="Users could not be loaded." onRetry={reload} /></Card>
      ) : users.length === 0 ? (
        <Card>
          <EmptyState
            icon={UsersIcon}
            title={isFiltered ? "No users match your filters" : "No users yet"}
            text={isFiltered ? "Try removing a filter or searching for something else." : "Registered accounts will appear here."}
          />
        </Card>
      ) : (
        <div style={{ opacity: loading ? 0.6 : 1, transition: "opacity var(--dur-base)" }}>
          <DataTable columns={columns} rows={users} caption="Users" />
        </div>
      )}
    </div>
  );
}
