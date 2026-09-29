namespace CeyloraAPI.DTOs
{
    public class HotelDto
    {
        public string Name { get; set; } = string.Empty;
        public string Region { get; set; } = string.Empty;
        public string? Address { get; set; }
        public int StarRating { get; set; }
        public decimal PricePerNight { get; set; }
        public int RoomsAvailable { get; set; }
        public string? Description { get; set; }
        public string? ImageUrl { get; set; }
    }
}