import { useState } from "react";
import { MessageSquareText, Search, Star, Trash2 } from "lucide-react";
import api from "../services/api";
import { Button, Card, EmptyState, ErrorState, IconButton, Input, PageHeader, Skeleton, useConfirm, useToast } from "../components/ui";
import { errorMessage } from "../lib/hooks";

function Stars({ rating }) {
  return (
    <span className="row" style={{ gap: 2 }} role="img" aria-label={`${rating} out of 5 stars`}>
      {[1, 2, 3, 4, 5].map((n) => (
        <Star key={n} size={16} aria-hidden="true" fill={n <= rating ? "currentColor" : "none"} style={{ color: n <= rating ? "var(--c-warning)" : "var(--c-border-strong)" }} />
      ))}
    </span>
  );
}

export default function ReviewsPage() {
  const [bookingId, setBookingId] = useState("");
  const [queried, setQueried] = useState(null); //booking id the current results belong to
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  const toast = useToast();
  const confirm = useConfirm();

  const fetchReviews = async (id = bookingId) => {
    if (!id) return;
    setLoading(true);
    setError(false);
    try {
      const res = await api.get(`/reviews/booking/${id}`);
      setReviews(res.data);
      setQueried(id);
    } catch (err) {
      console.error(err);
      setReviews([]);
      setError(true);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (r) => {
    const ok = await confirm({ title: "Delete this review?", message: "The review will be removed for everyone and cannot be restored.", confirmLabel: "Delete review" });
    if (!ok) return;
    try {
      await api.delete(`/reviews/${r.id}`);
      toast.success("Review deleted.");
      fetchReviews(queried);
    } catch (err) {
      toast.error(errorMessage(err, "Failed to delete review."));
    }
  };

  return (
    <div className="page">
      <PageHeader title="Reviews moderation" subtitle="Look up reviews by booking ID to read and moderate them." />

      <form
        className="toolbar"
        onSubmit={(e) => { e.preventDefault(); fetchReviews(); }}
        style={{ alignItems: "flex-end", maxWidth: 460 }}
      >
        <Input label="Booking ID" type="number" min="1" inputMode="numeric" placeholder="e.g. 128" value={bookingId} onChange={(e) => setBookingId(e.target.value)} className="search" />
        <Button type="submit" variant="primary" icon={Search} loading={loading} disabled={!bookingId}>Find reviews</Button>
      </form>

      {loading ? (
        <Card pad><Skeleton w="30%" h={16} /><Skeleton w="70%" style={{ marginTop: 12 }} /><Skeleton w="20%" style={{ marginTop: 12 }} /></Card>
      ) : error ? (
        <Card><ErrorState text="Reviews could not be loaded for that booking." onRetry={() => fetchReviews()} /></Card>
      ) : queried == null ? (
        <Card><EmptyState icon={MessageSquareText} title="Search for a booking" text="Enter a booking ID above to see the reviews tourists left for that trip." /></Card>
      ) : reviews.length === 0 ? (
        <Card><EmptyState icon={MessageSquareText} title="No reviews found" text={`Booking #${queried} doesn't have any reviews yet.`} /></Card>
      ) : (
        <div className="stack">
          {reviews.map((r) => (
            <Card key={r.id} pad interactive>
              <div className="row row--between" style={{ alignItems: "flex-start" }}>
                <div style={{ minWidth: 0 }}>
                  <Stars rating={r.rating} />
                  <p style={{ margin: "8px 0", whiteSpace: "pre-wrap" }}>{r.comment || <span className="muted">No comment left.</span>}</p>
                  <p className="muted" style={{ fontSize: "var(--fs-sm)" }}>{new Date(r.createdAt).toLocaleString()}</p>
                </div>
                <IconButton icon={Trash2} label="Delete review" variant="soft-danger" onClick={() => handleDelete(r)} />
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
