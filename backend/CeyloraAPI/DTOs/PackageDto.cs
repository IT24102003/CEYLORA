namespace CeyloraAPI.DTOs
{
    public class PackageDto
    {
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal BasePrice { get; set; }
        public int DurationDays { get; set; }
        public bool IsPublished { get; set; } = false;
    }
}