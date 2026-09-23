namespace CeyloraAPI.Models
{
    public enum BookingStatus { Pending, Confirmed, Cancelled, Completed }

    public class Booking
    {
        public int Id { get; set; }
        public int TouristId { get; set; }
        public User Tourist { get; set; } = null!;
        public int PackageId { get; set; }
        public Package Package { get; set; } = null!;
        public BookingStatus Status { get; set; } = BookingStatus.Pending;
        public decimal TotalPrice { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}