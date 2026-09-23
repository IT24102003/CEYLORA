namespace CeyloraAPI.Models
{
    public class Hotel
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Region { get; set; } = string.Empty;
        public string? Address { get; set; }
        public int StarRating { get; set; }
        public decimal PricePerNight { get; set; }
        public int RoomsAvailable { get; set; }
        public string? Description { get; set; }
        public string? ImageUrl { get; set; }          // Main/cover image
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<HotelImage> Images { get; set; } = new List<HotelImage>();
    }
}