namespace CeyloraAPI.Models
{
    public class Vehicle
    {
        public int Id { get; set; }
        public int OperatorId { get; set; }
        public User Operator { get; set; } = null!;
        public string Type { get; set; } = string.Empty; // "Car" | "Van" | "Bus"
        public string? Name { get; set; }
        public int? ManufacturerYear { get; set; }
        public int Capacity { get; set; } // number of seats
        public string Region { get; set; } = string.Empty;
        public decimal PricePerKm { get; set; }
        public bool IsAvailable { get; set; } = true;
        public double Rating { get; set; } = 0; // tourist-review average (0 = no reviews yet)

        public ICollection<VehicleImage> Images { get; set; } = new List<VehicleImage>();
    }
}