namespace CeyloraAPI.Models
{
    public class Review
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;
        public int TouristId { get; set; }
        public User Tourist { get; set; } = null!;
        public int Rating { get; set; }
        public string? Comment { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}