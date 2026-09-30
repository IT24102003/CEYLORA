namespace CeyloraAPI.Models
{
    // InProgress/Completed added at the END — existing values keep their int, no migration needed.
    public enum AssignmentStatus { Proposed, Confirmed, Cancelled, InProgress, Completed }

    public class Assignment
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;
        public int? GuideId { get; set; }
        public Guide? Guide { get; set; }
        public int? VehicleId { get; set; }
        public Vehicle? Vehicle { get; set; }
        public AssignmentStatus Status { get; set; } = AssignmentStatus.Proposed;
        public DateTime AssignedAt { get; set; } = DateTime.UtcNow;
    }
}