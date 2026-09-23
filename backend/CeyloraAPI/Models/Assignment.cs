namespace CeyloraAPI.Models
{
    public enum AssignmentStatus { Proposed, Confirmed, Cancelled }

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