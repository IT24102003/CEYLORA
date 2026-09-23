namespace CeyloraAPI.Models
{
    public class VehicleImage
    {
        public int Id { get; set; }
        public int VehicleId { get; set; }
        public Vehicle Vehicle { get; set; } = null!;
        public string ImageUrl { get; set; } = string.Empty;
        public bool IsCover { get; set; } = false;
        public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
    }
}