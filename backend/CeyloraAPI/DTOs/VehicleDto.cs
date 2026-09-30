namespace CeyloraAPI.DTOs
{
    public class VehicleDto
    {
        public int OperatorId { get; set; }
        public string Type { get; set; } = string.Empty;
        public string? Name { get; set; }
        public int? ManufacturerYear { get; set; }
        public int Capacity { get; set; }
        public string Region { get; set; } = string.Empty;
        public decimal PricePerKm { get; set; }
        public bool IsAvailable { get; set; } = true;
    }
}