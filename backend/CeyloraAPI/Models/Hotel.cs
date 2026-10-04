namespace CeyloraAPI.Models
{
    public class Hotel
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Region { get; set; } = string.Empty;
        public string? Address { get; set; }
        // 🔥 Optional — lets a hotel be included in the trip's driving route /
        // distance calculation alongside destinations (which already had
        // these). Null until an admin sets them on a hotel; the route/km
        // calc skips any hotel that doesn't have them yet.
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public int StarRating { get; set; }
        public double Rating { get; set; } = 0; // tourist-review average (0 = no reviews yet), separate from StarRating (hotel's official star class)
        public decimal PricePerNight { get; set; }
        public int RoomsAvailable { get; set; }
        public string? Description { get; set; }
        public string? ImageUrl { get; set; }          // Main/cover image
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<HotelImage> Images { get; set; } = new List<HotelImage>();
    }
}