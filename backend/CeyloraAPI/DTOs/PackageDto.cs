namespace CeyloraAPI.DTOs
{
    public class PackageDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal BasePrice { get; set; }
        public int DurationDays { get; set; }
        public bool IsPublished { get; set; }
        public List<DestinationDto> Destinations { get; set; } = new();
    }

    public class CreatePackageDto
    {
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal BasePrice { get; set; }
        public int DurationDays { get; set; }
        public bool IsPublished { get; set; } = true;
        public List<int> DestinationIds { get; set; } = new();
    }
}
