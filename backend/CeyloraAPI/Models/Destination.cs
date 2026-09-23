namespace CeyloraAPI.Models
{
    public class Destination
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Region { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string? Category { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string? ImageUrl { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}