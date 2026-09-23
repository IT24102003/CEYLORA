namespace CeyloraAPI.DTOs
{
    public class HotelImageDto
    {
        public int Id { get; set; }
        public string ImageUrl { get; set; } = string.Empty;
        public bool IsCover { get; set; }
    }

    public class HotelDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Region { get; set; } = string.Empty;
        public string? Address { get; set; }
        public int StarRating { get; set; }
        public decimal PricePerNight { get; set; }
        public int RoomsAvailable { get; set; }
        public string? Description { get; set; }
        public string? ImageUrl { get; set; }
        public List<HotelImageDto> Images { get; set; } = new();
    }

    public class CreateHotelDto
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
