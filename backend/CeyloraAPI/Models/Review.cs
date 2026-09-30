namespace CeyloraAPI.Models
{
    public class Review
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;
        public int TouristId { get; set; }
        public User Tourist { get; set; } = null!;
        public int Rating { get; set; } // overall trip rating (1-5)
        public string? Comment { get; set; }

        // Optional per-service ratings, submitted at the same time as the overall trip review.
        public int? HotelRating { get; set; }
        public int? VehicleRating { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}