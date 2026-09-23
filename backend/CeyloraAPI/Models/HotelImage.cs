namespace CeyloraAPI.Models
{
    public class HotelImage
    {
        public int Id { get; set; }
        public int HotelId { get; set; }
        public Hotel Hotel { get; set; } = null!;
        public string ImageUrl { get; set; } = string.Empty;
        public bool IsCover { get; set; } = false;
        public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
    }
}