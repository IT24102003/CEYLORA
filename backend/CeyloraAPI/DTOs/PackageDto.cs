namespace CeyloraAPI.DTOs
{
    public class PackageDto
    {
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal BasePrice { get; set; }
        public int DurationDays { get; set; }
        public int MaxPeople { get; set; } = 4;
        public int? SuggestedGuideId { get; set; }
        public int? SuggestedVehicleId { get; set; }
        public bool IsPublished { get; set; } = false;
    }

    public class AddPackageDestinationDto
    {
        public int DestinationId { get; set; }
        public int DayNumber { get; set; } = 1;
    }

    public class AddPackageHotelDto
    {
        public int HotelId { get; set; }
    }
}