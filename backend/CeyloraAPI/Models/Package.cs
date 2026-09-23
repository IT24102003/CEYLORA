namespace CeyloraAPI.Models
{
    public class Package
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal BasePrice { get; set; }
        public int DurationDays { get; set; }
        public bool IsPublished { get; set; } = false;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<PackageDestination> PackageDestinations { get; set; } = new List<PackageDestination>();
    }
}