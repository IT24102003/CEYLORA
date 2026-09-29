import { useState, useEffect } from "react";
import api from "../services/api";

export default function ReviewsPage() {
  const [bookingId, setBookingId] = useState("");
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  const fetchReviews = async () => {
    if (!bookingId) return;
    setLoading(true);
    setSearched(true);
    try {
      const res = await api.get(`/reviews/booking/${bookingId}`);
      setReviews(res.data);
    } catch (err) {
      console.error(err);
      setReviews([]);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm("Delete this review?")) return;
    try {
      await api.delete(`/reviews/${id}`);
      fetchReviews();
    } catch (err) {
      alert("Failed to delete.");
    }
  };

  return (
    <div style={{ padding: 20, fontFamily: "sans-serif" }}>
      <h2>Reviews Moderation</h2>
      <p style={{ color: "#666" }}>Look up reviews by Booking ID to moderate them.</p>

      <div style={{ marginBottom: 16, display: "flex", gap: 8 }}>
        <input
          type="number"
          placeholder="Booking ID"
          value={bookingId}
          onChange={(e) => setBookingId(e.target.value)}
          style={{ padding: 8, width: 150 }}
        />
        <button onClick={fetchReviews} style={{ padding: "8px 16px" }}>Search</button>
      </div>

      {loading && <p>Loading...</p>}

      {searched && !loading && reviews.length === 0 && (
        <p>No reviews found for this booking.</p>
      )}

      {reviews.map((r) => (
        <div key={r.id} style={{ border: "1px solid #ccc", borderRadius: 8, padding: 14, marginBottom: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between" }}>
            <div>
              <strong>{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</strong>
              <p style={{ margin: "4px 0" }}>{r.comment}</p>
              <p style={{ margin: 0, color: "#999", fontSize: 13 }}>
                {new Date(r.createdAt).toLocaleString()}
              </p>
            </div>
            <button onClick={() => handleDelete(r.id)} style={{ color: "red", alignSelf: "flex-start" }}>
              Delete
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}