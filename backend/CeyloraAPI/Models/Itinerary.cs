namespace CeyloraAPI.Models
{
    public enum ApprovalStatus { PendingApproval, Approved, Rejected, RevisionRequested }

    public class Itinerary
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;
        public string GeneratedBy { get; set; } = "AI"; // "AI" or "Manual"
        public ApprovalStatus ApprovalStatus { get; set; } = ApprovalStatus.PendingApproval;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<ItineraryDay> Days { get; set; } = new List<ItineraryDay>();
    }
}
