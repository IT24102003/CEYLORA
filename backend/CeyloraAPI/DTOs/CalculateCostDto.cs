namespace CeyloraAPI.DTOs
{
    public class CalculateCostRequestDto
    {
        public int? PackageId { get; set; }
        public List<int> DestinationIds { get; set; } = new();
        public int? HotelId { get; set; }
        public int DurationDays { get; set; } = 1;
        public int HotelNights { get; set; } = 1;
        public int GroupSize { get; set; } = 1;
        public bool IncludeVehicle { get; set; } = false;
        public bool IncludeGuide { get; set; } = false;
    }

    public class CalculateCostResponseDto
    {
        public decimal BaseDestinationsFee { get; set; }
        public decimal HotelTotalFee { get; set; }
        public decimal VehicleGuideFee { get; set; }
        public decimal ServiceFee { get; set; }
        public decimal TotalCost { get; set; }
        public string Currency { get; set; } = "LKR";
        public string BreakdownSummary { get; set; } = string.Empty;
    }
}
