namespace CeyloraAPI.Models
{
    public class Package
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal BasePrice { get; set; }
        public int DurationDays { get; set; }

        // Max number of people this package is designed for — shown to the admin when
        // assigning a vehicle to a booking of this package (vehicle Capacity must cover it).
        public int MaxPeople { get; set; } = 4;

        // A suggested/default guide & vehicle for this package (shown on the package itself).
        // The ACTUAL assignment for a specific booking still happens per-booking in the Admin
        // panel (so it can respect real-time availability + the tourist's actual group size).
        public int? SuggestedGuideId { get; set; }
        public Guide? SuggestedGuide { get; set; }
        public int? SuggestedVehicleId { get; set; }
        public Vehicle? SuggestedVehicle { get; set; }

        public bool IsPublished { get; set; } = false;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<PackageDestination> PackageDestinations { get; set; } = new List<PackageDestination>();
        public ICollection<PackageHotel> PackageHotels { get; set; } = new List<PackageHotel>();
    }
}