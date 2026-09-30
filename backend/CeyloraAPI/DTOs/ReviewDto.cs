namespace CeyloraAPI.DTOs
{
    public class CreateReviewDto
    {
        public int BookingId { get; set; }
        public int Rating { get; set; } // overall trip rating, 1 to 5
        public string? Comment { get; set; }

        // Optional — only sent if the tourist also rates the hotel/vehicle used on this trip.
        public int? HotelRating { get; set; }
        public int? VehicleRating { get; set; }
    }
}